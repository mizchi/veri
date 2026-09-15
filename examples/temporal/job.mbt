///|
pub(all) struct State {
  pending : Bool
  done : Bool
} derive(Eq, Debug)

///|
/// Drop is an explicit broken-protocol variant used to find lost requests.
pub(all) enum Action {
  Request
  Complete
  Wait
  Drop
} derive(Eq, Debug)

///|
#proof_pure
fn initial_model() -> State {
  { pending: false, done: false, }
}

///|
#proof_pure
fn safe_model(state : State) -> Bool {
  !(state.pending && state.done)
}

///|
#proof_pure
fn enabled_model(state : State, action : Action) -> Bool {
  match action {
    Request => !state.pending && !state.done
    Complete | Drop => state.pending && !state.done
    Wait => true
  }
}

///|
/// One definition is used by execution, .mbtp lemmas, and the model exporter.
/// An unavailable action returns None; waiting is an explicit successful step.
#proof_pure
fn step_model(state : State, action : Action) -> State? {
  if !enabled_model(state, action) {
    None
  } else {
    Some(
      match action {
        Request => { pending: true, done: false, }
        Complete => { pending: false, done: true, }
        Wait => state
        Drop => { pending: false, done: false, }
      },
    )
  }
}

///|
pub fn initial() -> State where {
  proof_ensure: state => initial_state(state),
  proof_ensure: state => safe_state(state),
} {
  initial_model()
}

///|
pub fn safe(
  state : State,
) -> Bool where {
  proof_ensure: valid => valid == safe_state(state),
} {
  safe_model(state)
}

///|
pub fn enabled(
  state : State,
  action : Action,
) -> Bool where {
  proof_ensure: available => available == action_enabled(state, action),
} {
  enabled_model(state, action)
}

///|
/// Contracted facade: current moon prove does not import proof_pure calls.
pub fn step(
  state : State,
  action : Action,
) -> State? where {
  proof_ensure: outcome => step_result(state, action, outcome),
  proof_ensure: outcome => safe_state(state) → safe_outcome(outcome),
} {
  step_model(state, action)
}

///|
pub fn state_code(
  state : State,
) -> Int where {
  proof_ensure: code => represents(state, code),
  proof_ensure: code => 0 <= code && code <= 3,
} {
  if state.pending {
    if state.done {
      3
    } else {
      1
    }
  } else if state.done {
    2
  } else {
    0
  }
}

///|
pub fn state_from_code(
  code : Int,
) -> State? where {
  proof_ensure: outcome => decoded(code, outcome),
} {
  if code == 0 {
    Some({ pending: false, done: false, })
  } else if code == 1 {
    Some({ pending: true, done: false, })
  } else if code == 2 {
    Some({ pending: false, done: true, })
  } else if code == 3 {
    Some({ pending: true, done: true, })
  } else {
    None
  }
}

///|
/// The external model's finite state identifiers preserve every actual State.
pub fn roundtrip(
  state : State,
) -> State? where {
  proof_ensure: outcome => same_outcome(outcome, Some(state)),
} {
  state_from_code(state_code(state))
}

///|
/// Execute an arbitrary finite action list. Invalid actions reject the trace.
pub fn replay(
  state : State,
  actions : @list.List[Action],
) -> State? where {
  proof_decrease: actions,
  proof_ensure: outcome => same_outcome(outcome, run(state, actions)),
  proof_ensure: outcome => safe_state(state) → safe_outcome(outcome),
} {
  match actions {
    Nil => Some(state)
    Cons(action, rest) =>
      match step(state, action) {
        None => None
        Some(next) => replay(next, rest)
      }
  }
}
