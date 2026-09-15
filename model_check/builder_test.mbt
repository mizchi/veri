///|
fn spec() -> @model_check.Spec[Int, Int, Int] {
  {
    initial: 0,
    actions: [("advance", 1), ("wait", 0)],
    step: (s, a) => if s + a <= 3 { Some(s + a) } else { None },
    predicates: [("safe", s => s < 3), ("done", s => s == 3)],
    snapshot: s => s,
    justice: ["advance"],
  }
}

///|
test "builder derives graph and replay from the same named definitions" {
  let client = @model_check.build_client(spec(), max_depth=3)
  assert_eq(client.model.states, [0, 1, 2, 3])
  assert_eq(client.model.transitions, [[1, 0], [2, 1], [3, 2], [-1, 3]])
  assert_eq(client.model.justice, [0])
  assert_true(client.model.exploration.unwrap().complete)
  assert_true(
    client.accepts(Safety("safe"), {
      states: [0, 1, 2, 3],
      actions: [0, 0, 0],
      loop_start: None,
    }),
  )
  let partial = @model_check.build_client(spec(), max_depth=1)
  assert_false(partial.model.exploration.unwrap().complete)
}

///|
test "builder rejects duplicate names and incomplete explicit domains" {
  let duplicated = { ..spec(), actions: [("x", 0), ("x", 1)], }
  assert_true(
    try {
      ignore(@model_check.build_client(duplicated))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@model_check.client_from_states(spec(), [0, 1]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@model_check.client_from_states(spec(), [0, 1, 2, 3, 3]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@model_check.build_client({ ..spec(), justice: ["unknown"], }))
      false
    } catch {
      _ => true
    },
  )
}
