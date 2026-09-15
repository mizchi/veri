///|
test "topological order, cycles and malformed witnesses" {
  let dag = try! @graph.Graph::from_array(
    [{ from: 0, to: 1, weight: 0, }, { from: 1, to: 2, weight: 1, }],
    vertex_count=4,
  )
  match dag.topological_sort() {
    Ordered(order) => assert_true(dag.check_topological_order(order))
    Cyclic(_) => fail("DAG reported as cyclic")
  }
  assert_false(dag.check_topological_order([0, 1, 1, 2]))
  assert_false(dag.check_topological_order([2, 1, 0, 3]))
  assert_false(dag.check_topological_order([0, 1, 2, 4]))
  assert_false(dag.check_cycle([0, 1, 2, 0]))
  assert_false(dag.check_cycle([]))
  assert_false(dag.check_cycle([0]))
  let self_loop = try! @graph.Graph::from_array(
    [{ from: 0, to: 0, weight: 0, }],
    vertex_count=1,
  )
  match self_loop.topological_sort() {
    Cyclic(cycle) => {
      assert_eq(cycle, [0, 0])
      assert_true(self_loop.check_cycle(cycle))
    }
    Ordered(_) => fail("self-self_loop accepted as DAG")
  }
  assert_false(self_loop.check_cycle([0, 0, 0]))
  let empty = try! @graph.Graph::new(vertex_count=0)
  assert_true(empty.check_topological_order([]))
  assert_true(empty.check_topology(Ordered([])))
  assert_false(empty.check_topology(Cyclic([])))
  assert_false(dag.check_topology(Ordered([2, 1, 0, 3])))
  assert_false(dag.check_topology(Cyclic([0, 1, 2, 0])))
}

///|
/// Independent reference: count/search in the supplied sequence, without a rank table.
fn order_reference(
  n : Int,
  edges : Array[@graph.Edge],
  order : ArrayView[Int],
) -> Bool {
  if order.length() != n {
    return false
  }
  for vertex = 0; vertex < n; vertex = vertex + 1 {
    if order.iter().filter(x => x == vertex).count() != 1 {
      return false
    }
  }
  for edge in edges {
    let mut source_position = -1
    let mut target_position = -1
    for i = 0; i < order.length(); i = i + 1 {
      if order[i] == edge.from {
        source_position = i
      }
      if order[i] == edge.to {
        target_position = i
      }
    }
    if source_position >= target_position {
      return false
    }
  }
  true
}

///|
/// Independent reference: pairwise uniqueness and original-input edge membership.
fn cycle_reference(
  n : Int,
  edges : Array[@graph.Edge],
  cycle : ArrayView[Int],
) -> Bool {
  if cycle.length() < 2 || cycle[0] != cycle[cycle.length() - 1] {
    return false
  }
  for i = 0; i < cycle.length() - 1; i = i + 1 {
    if cycle[i] < 0 || cycle[i] >= n {
      return false
    }
    for j = 0; j < i; j = j + 1 {
      if cycle[i] == cycle[j] {
        return false
      }
    }
    if !edges.any(edge => edge.from == cycle[i] && edge.to == cycle[i + 1]) {
      return false
    }
  }
  true
}

///|
test "quickcheck: topology checkers match independent arbitrary-witness oracles" {
  @quickcheck.check(
    (input : (Int, Array[(Int, Int)], Array[Int])) => {
      let (tag, raw_edges, raw_witness) = input
      let n = 2 + (tag % 6).abs()
      let dag = tag % 2 == 0
      let edges : Array[@graph.Edge] = []
      for (a, b) in raw_edges {
        let source = (a % n).abs()
        let target = (b % n).abs()
        if dag {
          if source != target {
            edges.push({
              from: source.min(target),
              to: source.max(target),
              weight: 0,
            })
          }
        } else {
          edges.push({ from: source, to: target, weight: 0, })
        }
      }
      if !dag {
        edges.push({ from: 0, to: 1, weight: 0, })
        edges.push({ from: 1, to: 0, weight: 0, })
      }
      let graph = try! @graph.Graph::from_array(edges, vertex_count=n)
      let topology = graph.topological_sort()
      if !graph.check_topology(topology) {
        return false
      }
      // Every sample has an accepted witness, for a known DAG or a forced cycle.
      match topology {
        Ordered(order) => {
          if !dag || !order_reference(n, edges, order[:]) {
            return false
          }
          let duplicate = order.copy()
          duplicate[0] = duplicate[1]
          if graph.check_topological_order(duplicate) {
            return false
          }
        }
        Cyclic(cycle) => {
          if dag || !cycle_reference(n, edges, cycle[:]) {
            return false
          }
          let open_path = cycle.copy()
          open_path[open_path.length() - 1] = (open_path[0] + 1) % n
          if graph.check_cycle(open_path) {
            return false
          }
        }
      }
      let candidate = raw_witness.map(x => x % (n + 2))
      let fixed = FixedArray::from_array(candidate)
      let ordered = order_reference(n, edges, candidate[:])
      let cyclic = cycle_reference(n, edges, candidate[:])
      // Nonzero-offset views exercise both compatibility adapters.
      let padded = [-2147483648]
      padded.append(candidate)
      padded.push(2147483647)
      let view = padded[1:padded.length() - 1]
      graph.check_topological_order(fixed) == ordered &&
      graph.check_cycle(fixed) == cyclic &&
      graph.check_topology(Ordered(fixed)) == ordered &&
      graph.check_topology(Cyclic(fixed)) == cyclic &&
      graph.check_topological_order_view(view) == ordered &&
      graph.check_cycle_view(view) == cyclic
    },
    count=1000,
    max_size=48,
    max_shrinks=1000,
    seed=20260927,
  )
}

///|
test "quickcheck: topological witnesses agree with transitive closure" {
  @quickcheck.check(
    (input : (Int, Array[(Int, Int)])) => {
      let (tag, raw) = input
      let n = (tag % 8).abs()
      let edges : Array[@graph.Edge] = if n == 0 {
        []
      } else {
        raw.map(pair => {
          from: (pair.0 % n).abs(),
          to: (pair.1 % n).abs(),
          weight: 0,
        })
      }
      let reach = Array::makei(n, _ => Array::make(n, false))
      for e in edges {
        reach[e.from][e.to] = true
      }
      for k = 0; k < n; k = k + 1 {
        for i = 0; i < n; i = i + 1 {
          for j = 0; j < n; j = j + 1 {
            reach[i][j] = reach[i][j] || (reach[i][k] && reach[k][j])
          }
        }
      }
      let cyclic = Array::makei(n, i => reach[i][i]).any(x => x)
      let graph = try! @graph.Graph::from_array(edges, vertex_count=n)
      match graph.topological_sort() {
        Ordered(order) => {
          if cyclic ||
            order.length() != n ||
            !graph.check_topological_order(order) {
            return false
          }
          let seen = Array::make(n, false)
          let rank = Array::make(n, -1)
          for i = 0; i < order.length(); i = i + 1 {
            let v = order[i]
            if v < 0 || v >= n || seen[v] {
              return false
            }
            seen[v] = true
            rank[v] = i
          }
          edges.all(e => rank[e.from] < rank[e.to])
        }
        Cyclic(cycle) => {
          if !cyclic ||
            !graph.check_cycle(cycle) ||
            cycle.length() < 2 ||
            cycle[0] != cycle[cycle.length() - 1] {
            return false
          }
          for i = 1; i < cycle.length(); i = i + 1 {
            if !edges.any(e => e.from == cycle[i - 1] && e.to == cycle[i]) {
              return false
            }
          }
          true
        }
      }
    },
    count=500,
    max_size=48,
    max_shrinks=1000,
    seed=20260921,
  )
}

///|
test "topological traversal is stack safe on a long chain" {
  let n = 20000
  let edges = Array::makei(n - 1, i => @graph.Edge::{
    from: i,
    to: i + 1,
    weight: 0,
  })
  let graph = try! @graph.Graph::from_array(edges, vertex_count=n)
  match graph.topological_sort() {
    Ordered(order) => assert_true(graph.check_topological_order(order))
    Cyclic(_) => fail("chain is acyclic")
  }
}

///|
test "cycle verification handles a long simple cycle and rejects a repeated lap" {
  let n = 20000
  let edges = Array::makei(n, i => @graph.Edge::{
    from: i,
    to: (i + 1) % n,
    weight: 0,
  })
  let graph = try! @graph.Graph::from_array(edges, vertex_count=n)
  let topology = graph.topological_sort()
  assert_true(graph.check_topology(topology))
  match topology {
    Cyclic(cycle) => {
      assert_eq(cycle.length(), n + 1)
      let repeated = FixedArray::makei(2 * n + 1, i => i % n)
      assert_false(graph.check_cycle(repeated))
    }
    Ordered(_) => fail("cycle was reported as acyclic")
  }
}
