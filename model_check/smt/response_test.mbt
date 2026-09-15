///|
fn response_model(
  transitions : Array[Array[Int]],
  pending : Array[Bool],
  done : Array[Bool],
) -> @model_check.Model[Json] {
  {
    initial: 0,
    states: Array::makei(transitions.length(), i => i.to_json()),
    actions: Array::makei(transitions[0].length(), i => "action-\{i}"),
    transitions,
    predicates: { "pending": pending, "done": done },
    justice: [],
    exploration: None,
  }
}

///|
test "complete response finds fair closed walks, including several simple cycles" {
  // Fairness requires both excursions from state 0; no single simple cycle suffices.
  let graph = response_model(
    [[1, 2], [0, 3], [3, 0], [3, 3]],
    [true, false, false, false],
    [false, false, false, true],
  )
  let result = @smt.exhaustive(graph, Response("pending", "done"), justice=[
    0, 1,
  ])
  assert_true(result.witness.unwrap().actions.length() >= 4)
  assert_true(
    @smt.evaluate(graph, Response("pending", "done"), result.witness.unwrap(), justice=[
      0, 1,
    ]),
  )
  let job = response_model(
    [[1, -1, 0], [-1, 2, 1], [-1, -1, 2]],
    [false, true, false],
    [false, false, true],
  )
  assert_true(
    @smt.exhaustive(job, Response("pending", "done")).witness is Some(_),
  )
  assert_eq(
    @smt.exhaustive(job, Response("pending", "done"), justice=[1]).witness,
    None,
  )
}

///|
// Independent oracle: transitive closure followed by a product of each potential
// loop entry, current state, and a bit mask of justice evidence. No SCC algorithm.
fn response_oracle(
  graph : @model_check.Model[Json],
  justice : Array[Int],
) -> Bool {
  let n = graph.states.length()
  let done = graph.predicates.get("done").unwrap()
  let pending = graph.predicates.get("pending").unwrap()
  let reachable = Array::makei(n, i => Array::makei(n, j => i == j))
  let avoiding = Array::makei(n, i => Array::makei(n, j => i == j && !done[i]))
  for state = 0; state < n; state = state + 1 {
    for next in graph.transitions[state] {
      if next >= 0 {
        reachable[state][next] = true
        if !done[state] && !done[next] {
          avoiding[state][next] = true
        }
      }
    }
  }
  for k = 0; k < n; k = k + 1 {
    for i = 0; i < n; i = i + 1 {
      for j = 0; j < n; j = j + 1 {
        reachable[i][j] = reachable[i][j] ||
          (reachable[i][k] && reachable[k][j])
        avoiding[i][j] = avoiding[i][j] || (avoiding[i][k] && avoiding[k][j])
      }
    }
  }
  let masks = 1 << justice.length()
  for entry = 0; entry < n; entry = entry + 1 {
    let mut outstanding = false
    for trigger = 0; trigger < n; trigger = trigger + 1 {
      if reachable[graph.initial][trigger] &&
        pending[trigger] &&
        avoiding[trigger][entry] {
        outstanding = true
      }
    }
    if !outstanding {
      continue
    }
    let seen = Array::make(n * masks, false)
    let queue = [(entry, 0)]
    let mut cursor = 0
    while cursor < queue.length() {
      let (state, mask) = queue[cursor]
      cursor += 1
      for action, next in graph.transitions[state] {
        if next < 0 || done[next] {
          continue
        }
        let mut evidence = mask
        for bit, fair in justice {
          let enabled = graph.transitions[state][fair]
          if enabled < 0 ||
            enabled == state ||
            (action == fair && next != state) {
            evidence = evidence | (1 << bit)
          }
        }
        if next == entry && evidence == masks - 1 {
          return true
        }
        let key = next * masks + evidence
        if !seen[key] {
          seen[key] = true
          queue.push((next, evidence))
        }
      }
    }
  }
  false
}

///|
test "complete response agrees with an independent product oracle with shrinking" {
  @quickcheck.check(
    (input : (Array[(UInt, UInt, UInt, Bool, Bool)], UInt)) => {
      let (rows, mask) = input
      let n = 1 + rows.length() % 5
      let transitions = Array::makei(n, state => {
        let (a, b, c, _, _) = rows.get(state).unwrap_or((0, 0, 0, true, false))
        [a, b, c].map(value => {
          (value % (n + 1).reinterpret_as_uint()).reinterpret_as_int() - 1
        })
      })
      let graph = response_model(
        transitions,
        Array::makei(n, state => {
          rows.get(state).map(row => row.3).unwrap_or(true)
        }),
        Array::makei(n, state => {
          rows.get(state).map(row => row.4).unwrap_or(false)
        }),
      )
      let justice = [0, 1, 2].filter(bit => (mask & (1U << bit)) != 0)
      let result = @smt.exhaustive(graph, Response("pending", "done"), justice~)
      (result.witness is Some(_)) == response_oracle(graph, justice) &&
      (match result.witness {
        None => true
        Some(w) =>
          @smt.evaluate(graph, Response("pending", "done"), w, justice~)
      })
    },
    count=3000,
    max_size=30,
    max_shrinks=1000,
    seed=20260916,
  )
}

///|
test "long response chains use an iterative traversal" {
  let n = 20000
  let graph = response_model(
    Array::makei(n, i => [if i + 1 < n { i + 1 } else { i }]),
    Array::makei(n, i => i == 0),
    Array::make(n, false),
  )
  let result = @smt.exhaustive(graph, Response("pending", "done"), justice=[0])
  let witness = result.witness.unwrap()
  assert_eq(witness.actions.length(), n)
  assert_eq(witness.loop_start, Some(n - 1))
  assert_true(
    @smt.evaluate(graph, Response("pending", "done"), witness, justice=[0]),
  )
}

///|
test "response needs a reachable unanswered trigger and an actual infinite execution" {
  for
    graph in [
      response_model([[1], [-1]], [true, false], [false, false]),
      response_model([[0], [1]], [false, true], [false, false]),
      response_model([[1], [1]], [true, false], [true, false]),
      response_model([[1], [2], [2]], [true, false, false], [false, true, false]),
    ] {
    assert_eq(@smt.exhaustive(graph, Response("pending", "done")).witness, None)
  }
  // The outstanding trigger is in the prefix, outside the eventual cycle.
  let graph = response_model([[1], [2], [2]], [true, false, false], [
    false, false, false,
  ])
  let result = @smt.exhaustive(graph, Response("pending", "done"))
  assert_true(
    @smt.evaluate(graph, Response("pending", "done"), result.witness.unwrap()),
  )
  // A self-loop is not enabled progress for the existing weak-fairness semantics.
  let stutter = response_model([[0, 0]], [true], [false])
  assert_true(
    @smt.exhaustive(stutter, Response("pending", "done"), justice=[1]).witness
    is Some(_),
  )
}

///|
test "complete response rejects truncated models and invalid fairness" {
  let graph = response_model([[0]], [true], [false])
  let partial = {
    ..graph,
    exploration: Some({
      complete: false,
      max_depth: 0,
      depths: [0],
      frontier: [0],
    }),
  }
  for (candidate, justice) in [(partial, []), (graph, [1]), (graph, [0, 0])] {
    assert_true(
      try {
        ignore(
          @smt.exhaustive(candidate, Response("pending", "done"), justice~),
        )
        false
      } catch {
        _ => true
      },
    )
  }
}
