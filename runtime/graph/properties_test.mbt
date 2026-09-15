///|
fn small(value : Int, bound : Int) -> Int {
  (value % bound).abs()
}

///|
/// Floyd-Warshall: an independent all-pairs matrix model, without queues or heaps.
fn distances(
  n : Int,
  edges : Array[@graph.Edge],
  weighted : Bool,
) -> Array[Array[Int]] {
  let matrix = Array::makei(n, i => {
    Array::makei(n, j => if i == j { 0 } else { 1000000 })
  })
  for edge in edges {
    let cost = if weighted { edge.weight } else { 1 }
    matrix[edge.from][edge.to] = matrix[edge.from][edge.to].min(cost)
  }
  for k = 0; k < n; k = k + 1 {
    for i = 0; i < n; i = i + 1 {
      for j = 0; j < n; j = j + 1 {
        matrix[i][j] = matrix[i][j].min(matrix[i][k] + matrix[k][j])
      }
    }
  }
  matrix
}

///|
fn agrees(n : Int, edges : Array[@graph.Edge]) -> Bool {
  let graph = try! @graph.Graph::from_array(edges, vertex_count=n)
  let unweighted = distances(n, edges, false)
  let weighted = distances(n, edges, true)
  for source = 0; source < n; source = source + 1 {
    let bfs = try! graph.bfs(source)
    let dijkstra = try! graph.dijkstra(source)
    if !graph.check_bfs(bfs) || !graph.check_dijkstra(dijkstra) {
      return false
    }
    for target = 0; target < n; target = target + 1 {
      let b = if unweighted[source][target] == 1000000 {
        None
      } else {
        Some(unweighted[source][target])
      }
      let d = if weighted[source][target] == 1000000 {
        None
      } else {
        Some(weighted[source][target])
      }
      if bfs.distance(target) != b || dijkstra.distance(target) != d {
        return false
      }
    }
  }
  true
}

///|
test "quickcheck: BFS and Dijkstra agree with independent all-pairs distances" {
  @quickcheck.check(
    (input : (Int, Array[(Int, Int, Int)])) => {
      let n = 1 + small(input.0, 7)
      let edges = input.1.map(e => @graph.Edge::{
        from: small(e.0, n),
        to: small(e.1, n),
        weight: small(e.2, 16),
      })
      agrees(n, edges)
    },
    count=500,
    max_size=48,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "quickcheck: graph edit traces replay and shrink from original inputs" {
  @quickcheck.check(
    (input : (Int, Array[(Int, Int, Int, Int)])) => {
      let n = 1 + small(input.0, 5)
      let edges : Array[@graph.Edge] = []
      for (tag, from, to, weight) in input.1 {
        match small(tag, 4) {
          0 | 1 =>
            edges.push({
              from: small(from, n),
              to: small(to, n),
              weight: small(weight, 8),
            })
          2 =>
            if !edges.is_empty() {
              edges.remove(small(from, edges.length())) |> ignore
            }
          _ => edges.clear()
        }
        if !agrees(n, edges) {
          return false
        }
      }
      true
    },
    count=200,
    max_size=24,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "graph sizes, edge weights, and operation traces all shrink" {
  let input : (Int, Array[(Int, Int, Int)]) = (7, [(4, 5, 9)])
  assert_true(@shrink.Shrink::shrink(input).any(x => x.0 == 0))
  assert_true(@shrink.Shrink::shrink(input).any(x => x.1.is_empty()))
  assert_true(
    @shrink.Shrink::shrink(input.1).any(x => x.length() == 1 && x[0].2 == 0),
  )
  let trace = [(1, 2, 3, 4), (2, 3, 4, 5)]
  assert_true(@shrink.Shrink::shrink(trace).any(x => x.is_empty()))
  assert_true(
    @shrink.Shrink::shrink(trace).any(x => x.length() == 2 && x[0].0 == 0),
  )
}

///|
test "quickcheck: a false graph law shrinks to one zero-weight edge" {
  let report = @quickcheck.report(
    (weights : Array[Int]) => {
      let edges = weights.mapi((i, w) => @graph.Edge::{
        from: i,
        to: i + 1,
        weight: small(w, 8),
      })
      let graph = try! @graph.Graph::from_array(
        edges,
        vertex_count=weights.length() + 1,
      )
      // Intentionally false: minimum edge count need not equal minimum weight.
      (try! graph.bfs(0)).distance(weights.length()) ==
      (try! graph.dijkstra(0)).distance(weights.length())
    },
    count=1000,
    max_size=8,
    max_shrinks=1000,
    seed=20260915,
  )
  let rendered = @debug.to_string(report)
  assert_true(rendered.has_prefix("Falsified("))
  assert_true(rendered.contains("counterexample=[0]"))
}
