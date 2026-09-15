///|
/// Compare initial observations, then each command's output and state snapshot.
/// index=-1 identifies an initial-state mismatch. Cleanup runs on every exit.
pub fn[M, S, C, O : Eq, V : Eq] replay(
  model : Model[M, C, O, V],
  system : System[S, C, O, V],
  commands : Array[C],
) -> Replay[O, V] raise {
  let mut actual = (system.create)()
  defer (system.close)(actual)
  let mut expected = (model.initial)()
  let before_expected = (model.observe)(expected)
  let before_actual = (system.observe)(actual)
  if before_expected != before_actual {
    return {
      verdict: Mismatch,
      index: -1,
      expected_output: None,
      actual_output: None,
      expected_state: Some(before_expected),
      actual_state: Some(before_actual),
    }
  }
  for index, command in commands {
    let (next, expected_output) = match (model.step)(expected, command) {
      None =>
        return {
          verdict: InvalidCommand,
          index,
          expected_output: None,
          actual_output: None,
          expected_state: None,
          actual_state: None,
        }
      Some(pair) => pair
    }
    expected = next
    let (next_actual, actual_output) = (system.step)(actual, command)
    actual = next_actual
    let expected_state = (model.observe)(expected)
    let actual_state = (system.observe)(actual)
    if expected_output != actual_output || expected_state != actual_state {
      return {
        verdict: Mismatch,
        index,
        expected_output: Some(expected_output),
        actual_output: Some(actual_output),
        expected_state: Some(expected_state),
        actual_state: Some(actual_state),
      }
    }
  }
  {
    verdict: Matched,
    index: commands.length(),
    expected_output: None,
    actual_output: None,
    expected_state: None,
    actual_state: None,
  }
}

///|
/// Core QuickCheck supplies generation, replayable seeds, and command/value shrinking.
/// Preconditions filter generation and shrink candidates instead of fabricating failures.
pub fn[
  M,
  S,
  C : @quickcheck.Arbitrary + @shrink.Shrink + @debug.Debug,
  O : Eq + @debug.Debug,
  V : Eq + @debug.Debug,
] check(
  model : Model[M, C, O, V],
  system : System[S, C, O, V],
  count? : UInt = 1000,
  max_size? : UInt = 128,
  max_shrinks? : UInt = 1000,
  seed? : UInt64 = 20260916,
) -> Unit raise {
  @quickcheck.check(
    (commands : Array[C]) => replay(model, system, commands).verdict == Matched,
    filter=commands => valid_trace(model, commands),
    counterexample_context=commands => {
      @debug.to_string(replay(model, system, commands)) catch {
        error => "Replay raised: " + @debug.to_string(error)
      }
    },
    count~,
    max_size~,
    max_shrinks~,
    seed~,
  )
}
