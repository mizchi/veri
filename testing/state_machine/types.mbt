///|
/// Independent reference model. None marks a command outside its precondition.
/// Return immutable observations, and create fresh model state for every replay.
pub(all) struct Model[M, C, O, V] {
  initial : () -> M
  step : (M, C) -> (M, O)?
  observe : (M) -> V
}

///|
/// Concrete implementation lifecycle. Expected errors belong in O (e.g. Result);
/// unexpected exceptions propagate and cannot become successful comparisons.
pub(all) struct System[S, C, O, V] {
  create : () -> S raise
  step : (S, C) -> (S, O) raise
  observe : (S) -> V raise
  close : (S) -> Unit
}

///|
pub(all) enum Verdict {
  Matched
  Mismatch
  InvalidCommand
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Replay[O, V] {
  verdict : Verdict
  index : Int
  expected_output : O?
  actual_output : O?
  expected_state : V?
  actual_state : V?
} derive(Debug, ToJson)

///|
pub fn[M, C, O, V] valid_trace(
  model : Model[M, C, O, V],
  commands : Array[C],
) -> Bool {
  let mut state = (model.initial)()
  for command in commands {
    match (model.step)(state, command) {
      None => return false
      Some((next, _)) => state = next
    }
  }
  true
}
