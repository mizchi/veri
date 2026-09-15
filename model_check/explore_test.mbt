///|
test "bounded exploration marks missing successors instead of inventing stutter" {
  let graph = @model_check.explore(
    0,
    [0, 1],
    (s, event) => Some(if event == 0 { s + 1 } else { 0 }),
    max_depth=3,
  )
  assert_eq(graph.states, [0, 1, 2, 3])
  assert_eq(graph.depths, [0, 1, 2, 3])
  assert_eq(graph.transitions, [[1, 0], [2, 0], [3, 0], [-1, 0]])
  assert_eq(graph.frontier, [3])
  assert_false(graph.complete)
}

///|
test "finite closure can be complete even with states at the depth limit" {
  let graph = @model_check.explore(0, [0], (s, _) => Some(1 - s), max_depth=1)
  assert_eq(graph.transitions, [[1], [0]])
  assert_true(graph.complete)
  assert_eq(graph.frontier, [])
  let zero = @model_check.explore(0, [0], (s, _) => Some(s), max_depth=0)
  assert_eq(zero.transitions, [[0]])
  assert_true(zero.complete)
}

///|
test "genuinely disabled actions and dead ends do not make exploration incomplete" {
  let graph = @model_check.explore(
    0,
    [0],
    (s, _) => if s == 0 { Some(1) } else { None },
    max_depth=3,
  )
  assert_eq(graph.transitions, [[1], [-1]])
  assert_true(graph.complete)
}

///|
test "resource limits raise a typed error without returning a partial success" {
  let result = try {
    ignore(
      @model_check.explore(
        0,
        [0],
        (s, _) => Some(s + 1),
        max_depth=3,
        max_states=2,
      ),
    )
    None
  } catch {
    error => Some(error)
  }
  assert_eq(result, Some(@model_check.StateLimitExceeded(2)))
}

///|
test "hashed exploration exceeds the old cap and resolves collisions" {
  let graph = @model_check.explore(
    0,
    [1],
    (s, _) => if s < 4999 { Some(s + 1) } else { None },
    max_depth=5000,
    max_states=5001,
    state_hash=s => s,
  )
  assert_eq(graph.states.length(), 5000)
  assert_true(graph.complete)
  let collide = @model_check.explore(
    0,
    [1],
    (s, _) => if s < 50 { Some(s + 1) } else { None },
    max_depth=51,
    state_hash=_ => 0,
  )
  let linear = @model_check.explore(
    0,
    [1],
    (s, _) => if s < 50 { Some(s + 1) } else { None },
    max_depth=51,
  )
  assert_eq(collide.states, linear.states)
  assert_eq(collide.transitions, linear.transitions)
  assert_true(
    try {
      ignore(
        @model_check.explore(
          0,
          [1, 2],
          (s, a) => Some(s + a),
          max_depth=20,
          max_transitions=4,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
}
