///|
pub fn default_policy() -> Policy where {
  proof_ensure: policy => default_settings(policy),
} {
  {
    first_no_wait: false,
    second_no_wait: false,
    first_allow_failure: false,
    second_allow_failure: false,
  }
}

///|
pub fn initial() -> State where {
  proof_ensure: state => initial_state(state),
  proof_ensure: state => valid_state(state),
} {
  initial_model()
}

///|
pub fn step(
  policy : Policy,
  state : State,
  event : Event,
) -> State? where {
  proof_ensure: outcome => step_result(policy, state, event, outcome),
  proof_ensure: outcome => valid_state(state) → safe_outcome(outcome),
} {
  step_model(policy, state, event)
}

///|
pub fn safe(
  state : State,
) -> Bool where {
  proof_ensure: valid => valid == valid_state(state),
} {
  invariant_model(state)
}

///|
pub fn no_orphans(
  state : State,
) -> Bool where {
  proof_ensure: valid => valid == children_joined(state),
} {
  no_orphans_model(state)
}

///|
pub fn terminal_resources_released(
  state : State,
) -> Bool where {
  proof_ensure: valid => valid == resources_safe(state),
} {
  resources_model(state)
}

///|
pub fn replay(
  policy : Policy,
  state : State,
  events : @list.List[Event],
) -> State? where {
  proof_decrease: events,
  proof_ensure: outcome => same_outcome(outcome, run(policy, state, events)),
  proof_ensure: outcome => valid_state(state) → safe_outcome(outcome),
} {
  match events {
    Nil => Some(state)
    Cons(event, rest) =>
      match step(policy, state, event) {
        None => None
        Some(next) => replay(policy, next, rest)
      }
  }
}
