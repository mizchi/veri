///|
fn run_model(
  variant : @lease_clock.Variant,
  events : Array[@lease_clock.Event],
) -> @lease_clock.State {
  @lease_clock.replay(variant, @lease_clock.initial(), events).unwrap()
}

///|
test "Quint clock skew witness: two writers after four actions" {
  let state = run_model(Vulnerable, [
    AdvanceTime,
    AdvanceTime,
    TakeOver(B),
    PublishCurrentOwner,
  ])
  assert_eq(state.now, 2)
  assert_eq(state.owner, B)
  assert_eq(state.epoch, 2)
  assert_eq(state.a.resident_epoch, 1)
  assert_eq(state.b.resident_epoch, 2)
  assert_true(@lease_clock.may_write(Vulnerable, state, A))
  assert_true(@lease_clock.may_write(Vulnerable, state, B))
  assert_false(@lease_clock.single_writer(Vulnerable, state))
  let early = run_model(BoundedSkew, [AdvanceTime, AdvanceTime])
  assert_eq(@lease_clock.step(BoundedSkew, early, TakeOver(B)), None)
}

///|
test "Quint repaired witness: ownership moves after the skew window" {
  let events : Array[@lease_clock.Event] = [
    AdvanceTime,
    RenewNodeLease(B),
    AdvanceTime,
    AdvanceTime,
    TakeOver(B),
    PublishCurrentOwner,
  ]
  let state = run_model(BoundedSkew, events)
  assert_eq(state.now, 3)
  assert_eq(state.owner, B)
  // A's resident still exists, but its monotonic authority has expired.
  assert_eq(state.a.resident_epoch, 1)
  assert_false(@lease_clock.may_write(BoundedSkew, state, A))
  assert_true(@lease_clock.may_write(BoundedSkew, state, B))
  assert_true(@lease_clock.single_writer(BoundedSkew, state))
  assert_eq(@lease_clock.step(BoundedSkew, state, RenewNodeLease(A)), None)
}

///|
test "TTL boundary, fencing and expired renewal differ between the two models" {
  let state = run_model(Vulnerable, [AdvanceTime, AdvanceTime, AdvanceTime])
  assert_eq(@lease_clock.step(Vulnerable, state, FenceExpiredNode(A)), None)
  let fenced = @lease_clock.step(BoundedSkew, state, FenceExpiredNode(A)).unwrap()
  assert_false(fenced.a.held)
  assert_eq(fenced.a.resident_epoch, 0)
  assert_true(state.a.held)
  assert_true(
    @lease_clock.step(Vulnerable, state, RenewNodeLease(A)) is Some(_),
  )
  assert_eq(@lease_clock.step(BoundedSkew, state, RenewNodeLease(A)), None)
}

///|
test "time bound does not bound vulnerable ownership epochs" {
  let mut state = run_model(Vulnerable, [
    AdvanceTime,
    AdvanceTime,
    AdvanceTime,
    AdvanceTime,
  ])
  for _ in 0..<20 {
    state = @lease_clock.step(Vulnerable, state, TakeOver(B)).unwrap()
    state = @lease_clock.step(Vulnerable, state, TakeOver(A)).unwrap()
  }
  assert_eq(state.now, 4)
  assert_eq(state.epoch, 41)
  assert_true(@lease_clock.single_writer(Vulnerable, state))
}

///|
test "disabled actions and the modeled time limit remain explicit" {
  let state = @lease_clock.initial()
  assert_true(@lease_clock.single_writer(Vulnerable, state))
  assert_eq(@lease_clock.step(Vulnerable, state, TakeOver(A)), None)
  assert_eq(@lease_clock.step(Vulnerable, state, PublishCurrentOwner), None)
  assert_eq(@lease_clock.replay(Vulnerable, state, [TakeOver(B)]), None)
  let mut end = state
  for _ in 0..<6 {
    end = @lease_clock.step(BoundedSkew, end, AdvanceTime).unwrap()
  }
  assert_eq(@lease_clock.step(BoundedSkew, end, AdvanceTime), None)
  assert_false(@lease_clock.may_write(BoundedSkew, end, A))
}

///|
test "quickcheck: repaired schedules preserve single writer with array shrinking" {
  @quickcheck.check(
    (schedule : Array[Int]) => {
      let mut state = @lease_clock.initial()
      let selected = []
      for raw in schedule {
        let enabled = @lease_clock.events().filter(e => {
          @lease_clock.step(BoundedSkew, state, e) is Some(_)
        })
        if enabled.is_empty() {
          break
        }
        let event = enabled[(raw % enabled.length()).abs()]
        let next = @lease_clock.step(BoundedSkew, state, event).unwrap()
        if !@lease_clock.single_writer(BoundedSkew, next) ||
          next.now < state.now {
          return false
        }
        selected.push(event)
        state = next
      }
      @lease_clock.replay(BoundedSkew, @lease_clock.initial(), selected) ==
      Some(state)
    },
    count=1000,
    max_size=80,
    max_shrinks=1000,
    seed=20260930,
  )
}
