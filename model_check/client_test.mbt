///|
fn client() -> @model_check.Client[Int, Int, Int] {
  {
    initial: 0,
    states: [0, 1, 2],
    events: [0, 1, 2],
    step: (s, a) => {
      match (s, a) {
        (0, 0) => Some(1)
        (1, 1) => Some(2)
        (_, 2) => Some(s)
        _ => None
      }
    },
    holds: (s, name) => {
      match name {
        "safe" => Some(s != 2)
        "pending" => Some(s == 1)
        "done" => Some(s == 2)
        _ => None
      }
    },
    model: {
      initial: 0,
      actions: ["request", "complete", "wait"],
      states: [0, 1, 2],
      transitions: [[1, -1, 0], [-1, 2, 1], [-1, -1, 2]],
      predicates: {
        "safe": [true, true, false],
        "pending": [false, true, false],
        "done": [false, false, true],
      },
      justice: [1],
      exploration: None,
    },
  }
}

///|
test "generic replay evaluates properties and rejects forged certificates" {
  let c = client()
  let w : @model_check.Witness = {
    states: [0, 1, 2],
    actions: [0, 1],
    loop_start: None,
  }
  assert_true(c.accepts(Safety("safe"), w))
  assert_true(c.accepts(Reachability("done"), w))
  assert_false(c.accepts(Safety("unknown"), w))
  assert_false(c.accepts(Safety("safe"), { ..w, states: [0, 2, 2], }))
  assert_false(c.accepts(Safety("safe"), { ..w, actions: [9, 1], }))
  assert_false(c.accepts(Safety("safe"), { ..w, states: [], }))
  assert_false(c.accepts(Safety("safe"), { ..w, loop_start: Some(0), }))
  assert_true(
    c.accepts(Reachability("safe"), {
      states: [0],
      actions: [],
      loop_start: None,
    }),
  )
  // A forged exported edge must not substitute for executing the real step.
  c.model.transitions[0][0] = 2
  assert_false(
    c.accepts(Safety("safe"), {
      states: [0, 2],
      actions: [0],
      loop_start: None,
    }),
  )
}

///|
test "generic response replay enforces changing-action weak fairness" {
  let c = client()
  let w : @model_check.Witness = {
    states: [0, 1, 1],
    actions: [0, 2],
    loop_start: Some(1),
  }
  assert_true(c.accepts(Response("pending", "done"), w))
  assert_false(c.accepts(Response("pending", "done"), w, justice=[1]))
  assert_true(c.accepts(Response("pending", "done"), w, justice=[2]))
  assert_false(c.accepts(Response("pending", "done"), w, justice=[99]))
  assert_false(
    c.accepts(Response("pending", "done"), { ..w, loop_start: Some(0), }),
  )
  assert_false(
    c.accepts(Response("pending", "done"), {
      states: [0, 1, 2, 2],
      actions: [0, 1, 2],
      loop_start: Some(2),
    }),
  )
}

///|
test "partial exploration cannot certify response or a trace beyond its depth" {
  let original = client()
  let c = {
    ..original,
    model: {
      ..original.model,
      exploration: Some({
        complete: false,
        max_depth: 1,
        depths: [0, 1, 1],
        frontier: [1],
      }),
    },
  }
  assert_false(
    c.accepts(Response("pending", "done"), {
      states: [0, 1, 1],
      actions: [0, 2],
      loop_start: Some(1),
    }),
  )
  assert_false(
    c.accepts(Safety("safe"), {
      states: [0, 1, 2],
      actions: [0, 1],
      loop_start: None,
    }),
  )
  assert_true(
    c.accepts(Reachability("pending"), {
      states: [0, 1],
      actions: [0],
      loop_start: None,
    }),
  )
}
