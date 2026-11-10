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

///|
test "query text is stable byte for byte" {
  // The encoder writes into one buffer; these snapshots pin its exact output.
  inspect(
    @smt.query_source(model(), Response("pending", "done"), 2, justice=[1]),
    content=(
      #|(set-logic QF_UFLIA)
      #|(declare-fun next (Int Int) Int)
      #|(assert (= (next 0 0) 1))
      #|(assert (= (next 0 1) -1))
      #|(assert (= (next 0 2) 0))
      #|(assert (= (next 1 0) -1))
      #|(assert (= (next 1 1) 2))
      #|(assert (= (next 1 2) 1))
      #|(assert (= (next 2 0) -1))
      #|(assert (= (next 2 1) -1))
      #|(assert (= (next 2 2) 2))
      #|(define-fun p1 ((s Int)) Bool (or (= s 0) (= s 1) (= s 2)))
      #|(define-fun p2 ((s Int)) Bool (or (= s 1)))
      #|(define-fun p0 ((s Int)) Bool (or (= s 2)))
      #|(declare-const s0 Int)
      #|(assert (= s0 0))
      #|(declare-const s1 Int)
      #|(assert (and (<= 0 s1) (< s1 3)))
      #|(declare-const a0 Int)
      #|(assert (and (<= 0 a0) (< a0 3)))
      #|(assert (= s1 (next s0 a0)))
      #|(declare-const s2 Int)
      #|(assert (and (<= 0 s2) (< s2 3)))
      #|(declare-const a1 Int)
      #|(assert (and (<= 0 a1) (< a1 3)))
      #|(assert (= s2 (next s1 a1)))
      #|(declare-const loop Int)
      #|(define-fun clear2 () Bool true)
      #|(define-fun clear1 () Bool (and (not (p0 s1)) clear2))
      #|(define-fun clear0 () Bool (and (not (p0 s0)) clear1))
      #|(assert (or (and (= loop 0) (= s2 s0) clear0 (or (and (p2 s0) clear0) (and (p2 s1) clear1)) (or (< (next s0 1) 0) (= (next s0 1) s0) (and (= a0 1) (not (= s0 s1))) (< (next s1 1) 0) (= (next s1 1) s1) (and (= a1 1) (not (= s1 s2))))) (and (= loop 1) (= s2 s1) clear1 (or (and (p2 s0) clear0) (and (p2 s1) clear1)) (or (< (next s1 1) 0) (= (next s1 1) s1) (and (= a1 1) (not (= s1 s2)))))))
      #|
    ),
  )
  inspect(
    @smt.condition_source(model(), Safety("safe"), 2),
    content=(
      #|(assert (or (not (p1 s0)) (not (p1 s1)) (not (p1 s2))))
      #|
    ),
  )
  inspect(
    @smt.condition_source(model(), Deadlock("done"), 1),
    content=(
      #|(define-fun deadlocked ((s Int)) Bool false)
      #|(assert (deadlocked s1))
      #|
    ),
  )
  inspect(
    @smt.condition_source(model(), Reachability("done"), 0),
    content=(
      #|(assert (p0 s0))
      #|
    ),
  )
  inspect(
    @smt.value_command(0, response=false),
    content=(
      #|(get-value (s0))
      #|
    ),
  )
  inspect(
    @smt.value_command(2, response=true),
    content=(
      #|(get-value (s0 s1 s2 a0 a1 loop))
      #|
    ),
  )
}

///|
test "witness decoding accepts any binding order and numeral spelling" {
  let ordered = @smt.decode_witness(
    "sat\n((s0 0)\n (s1 12)\n (s2 7)\n (a0 1)\n (a1 0)\n (loop 1))",
    2,
    response=true,
  )
  // The general decoder handles what the positional fast path declines.
  for
    source in [
      "sat ((loop 1) (a1 0) (a0 1) (s2 7) (s1 12) (s0 0))", "sat\n((s0 00) (s1 012) (s2 +7) (a0 1) (a1 0) (loop 1))",
      "sat((s0 0)(s1 12)(s2 7)(a0 1)(a1 0)(loop 1))",
    ] {
    assert_eq(@smt.decode_witness(source, 2, response=true), ordered)
  }
  assert_eq(ordered.states, [0, 12, 7])
  assert_eq(ordered.actions, [1, 0])
  assert_eq(ordered.loop_start, Some(1))
  for
    source in [
      "sat\n((s0 0) (s1 12) (s2 7) (a0 1) (a1 0))", "sat\n((s0 0) (s1 12) (s2 7) (a0 1) (a1 0) (loop 1) (loop 1))",
      "sat\n((s0 0) (s01 12) (s2 7) (a0 1) (a1 0) (loop 1))", "sat\n((s0 0) (s1 12) (s2 7) (a0 1) (a0 0) (loop 1))",
      "sat\n((s0 0) (s1 12) (s2 7) (a0 1) (a1 0) (lop 1))", "sat\n((s0 0) (s1 12) (s2 x) (a0 1) (a1 0) (loop 1))",
      "sat\n((s0 0) (s1 12) (s3 7) (a0 1) (a1 0) (loop 1))",
    ] {
    let rejected = try {
      ignore(@smt.decode_witness(source, 2, response=true))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=source)
  }
}
