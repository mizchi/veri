///|
/// Two nodes, TTL=3, maximum time=6, wall offsets A=0 and B=1.
/// Adapted from the linked Quint model; see README.md for provenance and scope.
pub fn initial() -> State {
  {
    now: 0,
    a: { expires: 3, elapsed: 0, held: true, resident_epoch: 1, },
    b: { expires: 4, elapsed: 0, held: true, resident_epoch: 0, },
    owner: A,
    epoch: 1,
  }
}

///|
fn node(state : State, id : Node) -> NodeState {
  match id {
    A => state.a
    B => state.b
  }
}

///|
fn with_node(state : State, id : Node, next : NodeState) -> State {
  match id {
    A => { ..state, a: next, }
    B => { ..state, b: next, }
  }
}

///|
fn wall_now(state : State, id : Node) -> Int {
  state.now + (if id == A { 0 } else { 1 })
}

///|
pub fn may_write(variant : Variant, state : State, id : Node) -> Bool {
  let lease = node(state, id)
  lease.held &&
  lease.resident_epoch > 0 &&
  (variant == Vulnerable || lease.elapsed < 3)
}

///|
pub fn single_writer(variant : Variant, state : State) -> Bool {
  !(may_write(variant, state, A) && may_write(variant, state, B))
}

///|
/// None means the Quint action's guard is false. Neither variant clamps epochs.
/// Representation overflow aborts the experiment instead of disabling an action.
pub fn step(variant : Variant, state : State, event : Event) -> State? {
  let repaired = variant == BoundedSkew
  match event {
    AdvanceTime => {
      guard state.now < 6 else { return None }
      Some({
        ..state,
        now: state.now + 1,
        a: { ..state.a, elapsed: state.a.elapsed + 1, },
        b: { ..state.b, elapsed: state.b.elapsed + 1, },
      })
    }
    RenewNodeLease(id) => {
      let lease = node(state, id)
      guard lease.held && (!repaired || lease.elapsed < 3) else { return None }
      Some(
        with_node(state, id, {
          ..lease,
          expires: wall_now(state, id) + 3,
          elapsed: 0,
        }),
      )
    }
    FenceExpiredNode(id) => {
      let lease = node(state, id)
      let expired = if repaired {
        lease.elapsed >= 3
      } else {
        lease.elapsed > 3
      }
      guard lease.held && expired else { return None }
      Some(with_node(state, id, { ..lease, held: false, resident_epoch: 0, }))
    }
    TakeOver(id) => {
      let lease = node(state, id)
      let grace = if repaired { 1 } else { 0 }
      guard lease.held &&
        (!repaired || lease.elapsed < 3) &&
        id != state.owner &&
        wall_now(state, id) >= node(state, state.owner).expires + grace else {
        return None
      }
      guard state.epoch < 0x7fff_ffff else {
        abort("Lease model epoch exceeds the runtime Int representation")
      }
      Some({ ..state, owner: id, epoch: state.epoch + 1, })
    }
    PublishCurrentOwner => {
      let lease = node(state, state.owner)
      guard lease.held &&
        (!repaired || lease.elapsed < 3) &&
        lease.resident_epoch != state.epoch else {
        return None
      }
      Some(
        with_node(state, state.owner, { ..lease, resident_epoch: state.epoch, }),
      )
    }
  }
}

///|
pub fn replay(
  variant : Variant,
  initial : State,
  events : Array[Event],
) -> State? {
  let mut state = initial
  for event in events {
    state = match step(variant, state, event) {
      None => return None
      Some(next) => next
    }
  }
  Some(state)
}

///|
pub fn events() -> Array[Event] {
  [
    AdvanceTime,
    RenewNodeLease(A),
    RenewNodeLease(B),
    FenceExpiredNode(A),
    FenceExpiredNode(B),
    TakeOver(A),
    TakeOver(B),
    PublishCurrentOwner,
  ]
}
