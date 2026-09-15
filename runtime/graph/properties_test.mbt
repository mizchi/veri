///|
fn small(value : Int, bound : Int) -> Int {
  (value % bound).abs()
}

///|
test "quickcheck: complete raw checker acceptance implies the independent optimum" {
  @quickcheck.check(
    (input : (Int, Array[(Int, Int, Int)], Array[Int?], Array[Int?])) => {
      let n = 1 + small(input.0, 6)
      let source = small(input.0 / 6, n)
      let edges = input.1.map(e => @graph.Edge::{
        from: small(e.0, n),
        to: small(e.1, n),
        weight: small(e.2, 8),
      })
      let graph = try! @graph.Graph::from_array(edges, vertex_count=n)
      let stored = graph.to_array()
      let edge_data = FixedArray::from_array(stored)
      for weighted in [false, true] {
        let result = if weighted {
          try! graph.dijkstra(source)
        } else {
          try! graph.bfs(source)
        }
        let ds = FixedArray::makei(n, vertex => result.distance(vertex))
        let ps = FixedArray::makei(n, vertex => {
          match result.path_to(vertex) {
            Some(path) =>
              if path.length() >= 2 {
                Some(path[path.length() - 2])
              } else {
                None
              }
            None => None
          }
        })
        // Every sample includes a known valid certificate; acceptance is nonvacuous.
        if !@checker.check_certificate(n, edge_data, ds, ps, source, weighted) {
          return false
        }
        let expected = distances(n, edges, weighted)[source]
        for vertex = 0; vertex < n; vertex = vertex + 1 {
          if ds[vertex].map(x => x.to_int64()) != expected[vertex] {
            return false
          }
        }
        // Arbitrary labels and parents, including invalid/negative indices and costs.
        // Standard tuple/array/option shrinkers retain small counterexamples.
        for vertex = 0; vertex < n; vertex = vertex + 1 {
          if vertex < input.2.length() {
            ds[vertex] = input.2[vertex].map(x => x % 16)
          }
          if vertex < input.3.length() {
            ps[vertex] = input.3[vertex].map(x => x % (n + 2))
          }
        }
        if @checker.check_certificate(n, edge_data, ds, ps, source, weighted) {
          for vertex = 0; vertex < n; vertex = vertex + 1 {
            if ds[vertex].map(x => x.to_int64()) != expected[vertex] {
              return false
            }
          }
        }
      }
      true
    },
    count=1000,
    max_size=32,
    max_shrinks=1000,
    seed=20260926,
  )
}

///|
/// Floyd-Warshall: an independent all-pairs matrix model, without queues or heaps.
/// None means unreachable. With at most seven vertices, Int64 safely holds sums
/// of Int weights, including shortest distances that the runtime must reject.
fn distances(
  n : Int,
  edges : Array[@graph.Edge],
  weighted : Bool,
) -> Array[Array[Int64?]] {
  let matrix = Array::makei(n, i => {
    Array::makei(n, j => if i == j { Some(0L) } else { None })
  })
  for edge in edges {
    let cost = if weighted { edge.weight.to_int64() } else { 1L }
    matrix[edge.from][edge.to] = Some(
      match matrix[edge.from][edge.to] {
        None => cost
        Some(old) => old.min(cost)
      },
    )
  }
  for k = 0; k < n; k = k + 1 {
    for i = 0; i < n; i = i + 1 {
      for j = 0; j < n; j = j + 1 {
        match (matrix[i][k], matrix[k][j]) {
          (Some(left), Some(right)) => {
            let candidate = left + right
            matrix[i][j] = Some(
              match matrix[i][j] {
                None => candidate
                Some(old) => old.min(candidate)
              },
            )
          }
          _ => ()
        }
      }
    }
  }
  matrix
}

///|
/// Validate against the original input, not Graph::edge_weight or its checker.
fn witness_matches(
  n : Int,
  edges : Array[@graph.Edge],
  source : Int,
  target : Int,
  expected : Int64?,
  path : Array[Int]?,
  weighted : Bool,
) -> Bool {
  match (expected, path) {
    (None, None) => true
    (Some(cost), Some(vertices)) => {
      if vertices.is_empty() ||
        vertices.length() > n ||
        vertices[0] != source ||
        vertices[vertices.length() - 1] != target ||
        vertices.any(v => v < 0 || v >= n) {
        return false
      }
      let mut total = 0L
      for i = 1; i < vertices.length(); i = i + 1 {
        let mut best : Int64? = None
        for edge in edges {
          if edge.from == vertices[i - 1] && edge.to == vertices[i] {
            let weight = if weighted { edge.weight.to_int64() } else { 1L }
            best = Some(
              match best {
                None => weight
                Some(old) => old.min(weight)
              },
            )
          }
        }
        match best {
          None => return false
          Some(weight) => total += weight
        }
      }
      total == cost
    }
    _ => false
  }
}

///|
fn result_matches(
  n : Int,
  edges : Array[@graph.Edge],
  source : Int,
  result : @graph.SearchResult,
  expected : Array[Int64?],
  weighted : Bool,
) -> Bool {
  if result.source() != source {
    return false
  }
  for target = 0; target < n; target = target + 1 {
    if result.distance(target).map(x => x.to_int64()) != expected[target] ||
      !witness_matches(
        n,
        edges,
        source,
        target,
        expected[target],
        result.path_to(target),
        weighted,
      ) {
      return false
    }
  }
  true
}

///|
fn agrees(n : Int, edges : Array[@graph.Edge]) -> Bool {
  let graph = try! @graph.Graph::from_array(edges, vertex_count=n)
  let unweighted = distances(n, edges, false)
  let weighted = distances(n, edges, true)
  for source = 0; source < n; source = source + 1 {
    let bfs = try! graph.bfs(source)
    if !graph.check_bfs(bfs) ||
      !result_matches(n, edges, source, bfs, unweighted[source], false) {
      return false
    }
    let dijkstra = graph.dijkstra(source) catch {
      @graph.DistanceOverflow(vertex) => {
        if vertex < 0 || vertex >= n {
          return false
        }
        match weighted[source][vertex] {
          Some(cost) => if cost <= 2147483647L { return false }
          None => return false
        }
        continue
      }
      _ => return false
    }
    if !graph.check_dijkstra(dijkstra) ||
      !result_matches(n, edges, source, dijkstra, weighted[source], true) {
      return false
    }
  }
  true
}

///|
test "graph reference covers Int limits and unrepresentable shortest paths" {
  assert_true(agrees(2, [{ from: 0, to: 1, weight: 2147483647, }]))
  assert_true(
    agrees(4, [
      { from: 0, to: 1, weight: 2147483647, },
      { from: 1, to: 2, weight: 1, },
    ]),
  )
  assert_true(
    agrees(4, [
      { from: 0, to: 1, weight: 2147483647, },
      { from: 1, to: 2, weight: 1, },
      { from: 0, to: 2, weight: 3, },
    ]),
  )
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
test "quickcheck: Dijkstra distinguishes large finite distances, overflow and unreachability" {
  let weights = [0, 1, 2, 16, 1073741823, 1073741824, 2147483646, 2147483647]
  @quickcheck.check(
    (input : (Int, Array[(Int, Int, Int)])) => {
      let n = 1 + small(input.0, 7)
      let edges = input.1.map(e => @graph.Edge::{
        from: small(e.0, n),
        to: small(e.1, n),
        weight: weights[small(e.2, weights.length())],
      })
      agrees(n, edges)
    },
    count=500,
    max_size=48,
    max_shrinks=1000,
    seed=20260916,
  )
}

///|
test "quickcheck: distances survive vertex relabeling and edge reordering" {
  @quickcheck.check(
    (input : (Int, Array[(Int, Int, Int)])) => {
      let n = 1 + small(input.0, 7)
      let edges = input.1.map(e => @graph.Edge::{
        from: small(e.0, n),
        to: small(e.1, n),
        weight: small(e.2, 16),
      })
      let renamed = edges
        .rev()
        .map(e => @graph.Edge::{
          from: n - 1 - e.from,
          to: n - 1 - e.to,
          weight: e.weight,
        })
      let original = try! @graph.Graph::from_array(edges, vertex_count=n)
      let permuted = try! @graph.Graph::from_array(renamed, vertex_count=n)
      for source = 0; source < n; source = source + 1 {
        let bfs = try! original.bfs(source)
        let other_bfs = try! permuted.bfs(n - 1 - source)
        let dijkstra = try! original.dijkstra(source)
        let other_dijkstra = try! permuted.dijkstra(n - 1 - source)
        for target = 0; target < n; target = target + 1 {
          if bfs.distance(target) != other_bfs.distance(n - 1 - target) ||
            dijkstra.distance(target) != other_dijkstra.distance(n - 1 - target) {
            return false
          }
        }
      }
      true
    },
    count=500,
    max_size=48,
    max_shrinks=1000,
    seed=20260917,
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
