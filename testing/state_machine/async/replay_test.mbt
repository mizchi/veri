///|
fn model() -> @state_machine.Model[Int, Int, Int, Int] {
  {
    initial: () => 0,
    step: (state, command) => Some((state + command, state + command)),
    observe: s => s,
  }
}

///|
fn system(
  broken : Bool,
  closed : Array[Int],
) -> @async.System[Int, Int, Int, Int] {
  {
    create: () => 0,
    step: (state, command) => {
      @moon_async.pause()
      let next = state + command + (if broken && command >= 3 { 1 } else { 0 })
      (next, next)
    },
    observe: s => s,
    close: _ => closed.push(1),
  }
}

///|
async test "async differential replay and shrinking use fresh lifecycles" {
  let closed = []
  let result = @async.replay(model(), system(false, closed), [1, 2, 3])
  assert_eq(result.verdict, @state_machine.Matched)
  assert_eq(closed.length(), 1)
  let failure = @async.find_failure(
    model(),
    system(true, closed),
    count=100,
    max_size=16,
    seed=20260916,
  ).unwrap()
  assert_eq(failure.commands, [3])
  assert_eq(failure.replay.verdict, @state_machine.Mismatch)
  assert_true(closed.length() > 2)
}

///|
async test "async timeout still closes the concrete implementation" {
  let closed = []
  let slow = {
    ..system(false, closed),
    step: (state, command) => {
      @moon_async.sleep(1000)
      (state + command, state + command)
    },
  }
  assert_true(
    try {
      ignore(@async.replay(model(), slow, [1], timeout_ms=20))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(closed.length(), 1)
}
