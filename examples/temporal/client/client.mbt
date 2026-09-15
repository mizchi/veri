///|
/// A normal contracted client consumes the same pure step and proved lemma.
pub fn checked_step(
  state : @temporal.State,
  action : @temporal.Action,
) -> @temporal.State? where {
  proof_require: @temporal.safe_state(state),
  proof_ensure: outcome => @temporal.safe_outcome(outcome),
  proof_ensure: outcome => @temporal.step_result(state, action, outcome),
} {
  @temporal.step(state, action)
}

///|
/// Safety holds for any finite trace, independently of the SMT exploration bound.
pub fn checked_trace(
  actions : @list.List[@temporal.Action],
) -> @temporal.State? where {
  proof_ensure: outcome => @temporal.safe_outcome(outcome),
} {
  @temporal.replay(@temporal.initial(), actions)
}
