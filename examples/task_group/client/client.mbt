///|
pub fn checked_step(
  policy : @task_group.Policy,
  state : @task_group.State,
  event : @task_group.Event,
) -> @task_group.State? where {
  proof_require: @task_group.valid_state(state),
  proof_ensure: result => @task_group.safe_outcome(result),
  proof_ensure: result => @task_group.step_result(policy, state, event, result),
} {
  @task_group.step(policy, state, event)
}

///|
pub fn checked_trace(
  policy : @task_group.Policy,
  events : @list.List[@task_group.Event],
) -> @task_group.State? where {
  proof_ensure: result => @task_group.safe_outcome(result),
} {
  @task_group.replay(policy, @task_group.initial(), events)
}

///|
pub fn checked_default_trace(
  events : @list.List[@task_group.Event],
) -> @task_group.State? where {
  proof_ensure: result => @task_group.safe_outcome(result),
} {
  @task_group.replay(
    @task_group.default_policy(),
    @task_group.initial(),
    events,
  )
}
