///|
test "pure transition shares the executable and proof model" {
  let idle = @temporal.initial()
  let pending = @temporal.step(idle, Request).unwrap()
  assert_true(pending.pending)
  assert_false(pending.done)
  assert_eq(@temporal.step(idle, Complete), None)
  assert_eq(@temporal.step(pending, Wait), Some(pending))
  let done = @temporal.step(pending, Complete).unwrap()
  assert_true(@temporal.safe(done))
  assert_true(done.done)
  assert_eq(@temporal.step(pending, Drop), Some(idle))
}

///|
test "state encoding and every available action agree with the finite reference" {
  let choices : Array[@temporal.Action] = [Request, Complete, Wait, Drop]
  let expected = [
    [1, -1, 0, -1],
    [-1, 2, 1, 0],
    [-1, -1, 2, -1],
    [-1, -1, 3, -1],
  ]
  for code = 0; code < 4; code = code + 1 {
    let state = @temporal.state_from_code(code).unwrap()
    assert_eq(@temporal.state_code(state), code)
    assert_eq(@temporal.roundtrip(state), Some(state))
    for action = 0; action < choices.length(); action = action + 1 {
      let next = @temporal.step(state, choices[action])
      assert_eq(
        next.map(@temporal.state_code).unwrap_or(-1),
        expected[code][action],
      )
      assert_eq(
        @temporal.enabled(state, choices[action]),
        expected[code][action] >= 0,
      )
    }
  }
  for invalid in [-2147483648, -1, 4, 2147483647] {
    assert_eq(@temporal.state_from_code(invalid), None)
  }
}

///|
test "quickcheck: proved trace execution matches a finite reference with shrinking" {
  let choices : Array[@temporal.Action] = [Request, Complete, Wait, Drop]
  let reference = [
    [1, -1, 0, -1],
    [-1, 2, 1, 0],
    [-1, -1, 2, -1],
    [-1, -1, 3, -1],
  ]
  @quickcheck.check(
    (input : (Int, Array[Int])) => {
      let (tag, raw) = input
      let code = (tag % 4).abs()
      let state = @temporal.state_from_code(code).unwrap()
      let indices = raw.map(value => (value % 4).abs())
      let mut expected = code
      for action in indices {
        if expected >= 0 {
          expected = reference[expected][action]
        }
      }
      let actions = @list.List::from_iter(indices.iter().map(i => choices[i]))
      let actual = @temporal.replay(state, actions)
      actual.map(@temporal.state_code).unwrap_or(-1) == expected
    },
    count=1000,
    max_size=80,
    max_shrinks=1000,
    seed=20260928,
  )
}
