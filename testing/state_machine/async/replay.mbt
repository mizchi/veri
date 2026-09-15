///|
/// Async implementation adapter. One supplied command is awaited at a time;
/// adapters define any scheduler control or explicit cancellation inside it.
pub(all) struct System[S, C, O, V] {
  create : async () -> S
  step : async (S, C) -> (S, O)
  observe : async (S) -> V
  close : async (S) -> Unit
}

///|
pub(all) struct Failure[C, O, V] {
  commands : Array[C]
  replay : @state_machine.Replay[O, V]
  shrink_attempts : Int
  seed : UInt64
} derive(Debug, ToJson)

///|
pub(all) suberror CheckError {
  InvalidOptions
  Exhausted
  NotAMismatch
} derive(Debug)

///|
pub async fn[M, S, C, O : Eq, V : Eq] replay(
  model : @state_machine.Model[M, C, O, V],
  system : System[S, C, O, V],
  commands : Array[C],
  timeout_ms? : Int = 1000,
) -> @state_machine.Replay[O, V] {
  guard timeout_ms > 0 else { raise InvalidOptions }
  @moon_async.with_timeout(timeout_ms, () => {
    let mut actual = (system.create)()
    defer @moon_async.protect_from_cancel(() => {
      @moon_async.with_timeout(timeout_ms, () => (system.close)(actual))
    })
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
  })
}

///|
/// Use core command/array shrinkers; invalid command sequences cannot replace a failure.
pub async fn[M, S, C : @shrink.Shrink, O : Eq, V : Eq] shrink_failure(
  model : @state_machine.Model[M, C, O, V],
  system : System[S, C, O, V],
  commands : Array[C],
  max_shrinks? : Int = 1000,
  timeout_ms? : Int = 1000,
  seed? : UInt64 = 20260916,
) -> Failure[C, O, V] {
  guard max_shrinks >= 0 else { raise InvalidOptions }
  let mut current = commands.copy()
  let mut result = replay(model, system, current, timeout_ms~)
  guard result.verdict == @state_machine.Mismatch else { raise NotAMismatch }
  let mut attempts = 0
  while attempts < max_shrinks {
    let mut improved = false
    for candidate in @shrink.Shrink::shrink(current) {
      if attempts == max_shrinks {
        break
      }
      attempts += 1
      if !@state_machine.valid_trace(model, candidate) {
        continue
      }
      let checked = replay(model, system, candidate, timeout_ms~)
      if checked.verdict == @state_machine.Mismatch {
        current = candidate
        result = checked
        improved = true
        break
      }
    }
    if !improved {
      break
    }
  }
  { commands: current, replay: result, shrink_attempts: attempts, seed, }
}

///|
/// Async properties use core's generator and shrinker with a deterministic seed.
/// Excessive precondition discards raise Exhausted rather than passing vacuously.
pub async fn[M, S, C : @quickcheck.Arbitrary + @shrink.Shrink, O : Eq, V : Eq] find_failure(
  model : @state_machine.Model[M, C, O, V],
  system : System[S, C, O, V],
  count? : Int = 1000,
  max_size? : Int = 128,
  max_shrinks? : Int = 1000,
  seed? : UInt64 = 20260916,
  timeout_ms? : Int = 1000,
) -> Failure[C, O, V]? {
  guard count > 0 &&
    count <= 1000000 &&
    max_size >= 0 &&
    max_size <= 1000000 &&
    max_shrinks >= 0 else {
    raise InvalidOptions
  }
  let state = @splitmix.new(seed~)
  let mut accepted = 0
  let mut draws = 0
  while accepted < count {
    guard draws < count * 10 else { raise Exhausted }
    draws += 1
    let commands : Array[C] = @quickcheck.gen(size=max_size, state~)
    if !@state_machine.valid_trace(model, commands) {
      continue
    }
    accepted += 1
    let result = replay(model, system, commands, timeout_ms~)
    if result.verdict == @state_machine.Mismatch {
      return Some(
        shrink_failure(
          model,
          system,
          commands,
          max_shrinks~,
          timeout_ms~,
          seed~,
        ),
      )
    }
  }
  None
}
