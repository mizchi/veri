///|
fn model() -> @model_check.Model[Json] {
  {
    initial: 0,
    actions: ["request", "complete", "wait"],
    states: [0, 1, 2],
    transitions: [[1, -1, 0], [-1, 2, 1], [-1, -1, 2]],
    predicates: {
      "safe": [true, true, true],
      "pending": [false, true, false],
      "done": [false, false, true],
    },
    justice: [1],
    exploration: None,
  }
}

///|
test "decoded solver certificates replay with and without fairness" {
  let w = @smt.decode_witness(
    "sat\n((s0 0) (s1 1) (s2 1) (a0 0) (a1 2) (loop 1))",
    2,
    response=true,
  )
  assert_eq(w.states, [0, 1, 1])
  assert_true(@smt.evaluate(model(), Response("pending", "done"), w))
  assert_false(
    @smt.evaluate(model(), Response("pending", "done"), w, justice=[1]),
  )
  let initial = @smt.decode_witness("sat\n((s0 0))", 0, response=false)
  assert_true(@smt.evaluate(model(), Reachability("safe"), initial))
}

///|
test "malformed solver output never becomes a certificate" {
  for
    source in [
      "unknown", "unsat", "sat\n((s0 0) (s0 0))", "sat\n((s0 (- 1)))", "sat\n((s0 0) (extra 1))",
      "sat\n((s0 0)) garbage", "sat\n()",
    ] {
    let rejected = try {
      ignore(@smt.decode_witness(source, 0, response=false))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "SMT generation validates scope and never uses predicate names as symbols" {
  let graph = model()
  graph.predicates.set("unsafe ) (exit)", [true, false, false])
  let source = @smt.query_source(graph, Safety("unsafe ) (exit)"), 2)
  assert_false(source.contains("(exit)"))
  let partial = {
    ..graph,
    exploration: Some({
      complete: false,
      max_depth: 1,
      depths: [0, 1, 1],
      frontier: [1],
    }),
  }
  for
    (property, depth) in [
      (@model_check.Response("pending", "done"), 1),
      (@model_check.Safety("safe"), 2),
      (@model_check.Safety("unknown"), 1),
    ] {
    let rejected = try {
      ignore(@smt.query_source(partial, property, depth))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "deadlock excludes normal termination and incomplete frontier rows" {
  let graph = {
    ..model(),
    transitions: [[1, -1, -1], [-1, -1, -1], [-1, -1, -1]],
  }
  let witness : @model_check.Witness = {
    states: [0, 1],
    actions: [0],
    loop_start: None,
  }
  assert_true(@smt.evaluate(graph, Deadlock("done"), witness))
  assert_false(@smt.evaluate(model(), Deadlock("done"), witness))
  assert_true(@smt.query_source(graph, Deadlock("done"), 1).contains("(= s 1)"))
  let partial = {
    ..graph,
    exploration: Some({
      complete: false,
      max_depth: 1,
      depths: [0, 1, 1],
      frontier: [1],
    }),
  }
  assert_false(
    @smt.query_source(partial, Deadlock("done"), 1).contains(
      "(define-fun deadlocked ((s Int)) Bool (or (= s 1)))",
    ),
  )
}

///|
test "complete checking reaches all states and never accepts truncated graphs" {
  let result = @smt.exhaustive(model(), Safety("safe"))
  assert_eq(result.visited, 3)
  assert_eq(result.witness, None)
  let reached = @smt.exhaustive(model(), Reachability("done"))
  assert_eq(reached.witness.unwrap().states, [0, 1, 2])
  let partial = {
    ..model(),
    exploration: Some({
      complete: false,
      max_depth: 1,
      depths: [0, 1, 1],
      frontier: [1],
    }),
  }
  assert_true(
    try {
      ignore(@smt.exhaustive(partial, Safety("safe")))
      false
    } catch {
      _ => true
    },
  )
}
