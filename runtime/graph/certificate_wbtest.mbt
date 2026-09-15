///|
test "certificate checker rejects missing reachable vertices and fabricated distances" {
  let g = Graph::from_array(
    [{ from: 0, to: 1, weight: 2, }, { from: 1, to: 2, weight: 3, }],
    vertex_count=3,
  )
  let missing : SearchResult = {
    origin: 0,
    distances: [Some(0), Some(2), None],
    parents: [None, Some(0), None],
  }
  assert_false(g.check_dijkstra(missing))
  let cheap : SearchResult = {
    origin: 0,
    distances: [Some(0), Some(1), Some(2)],
    parents: [None, Some(0), Some(1)],
  }
  assert_false(g.check_dijkstra(cheap))
  let wrong_parent : SearchResult = {
    origin: 0,
    distances: [Some(0), Some(2), Some(5)],
    parents: [None, Some(0), Some(0)],
  }
  assert_false(g.check_dijkstra(wrong_parent))
  let malformed : SearchResult = {
    origin: 0,
    distances: [Some(0)],
    parents: [None],
  }
  assert_false(g.check_bfs(malformed))
  let detached : SearchResult = {
    origin: 0,
    distances: [Some(0), None, None],
    parents: [None, None, Some(1)],
  }
  assert_false(g.check_bfs(detached))
}

///|
test "zero-weight predecessor cycles cannot certify unreachable vertices" {
  let g = Graph::from_array(
    [{ from: 1, to: 2, weight: 0, }, { from: 2, to: 1, weight: 0, }],
    vertex_count=3,
  )
  let cyclic : SearchResult = {
    origin: 0,
    distances: [Some(0), Some(0), Some(0)],
    parents: [None, Some(2), Some(1)],
  }
  assert_false(g.check_dijkstra(cyclic))
  assert_eq(cyclic.path_to(1), None)
  let invalid : SearchResult = {
    origin: 0,
    distances: [Some(0), Some(0), Some(0)],
    parents: [None, Some(9), Some(1)],
  }
  assert_false(g.check_dijkstra(invalid))
}

///|
fn rejects_corruptions(
  graph : Graph,
  result : SearchResult,
  weighted : Bool,
) -> Bool {
  let accepts = fn(candidate) {
    if weighted {
      graph.check_dijkstra(candidate)
    } else {
      graph.check_bfs(candidate)
    }
  }
  if !accepts(result) {
    return false
  }
  for vertex = 1; vertex < graph.vertex_count(); vertex = vertex + 1 {
    guard result.distance(vertex) is Some(cost) else { continue }
    let wrong_distance = result.distances.copy()
    // Generated weights are small, so this mutation cannot wrap.
    wrong_distance[vertex] = Some(cost + 1)
    if accepts({
        origin: result.origin,
        distances: wrong_distance,
        parents: result.parents.copy(),
      }) {
      return false
    }
    let hidden_distance = result.distances.copy()
    let hidden_parent = result.parents.copy()
    hidden_distance[vertex] = None
    hidden_parent[vertex] = None
    if accepts({
        origin: result.origin,
        distances: hidden_distance,
        parents: hidden_parent,
      }) {
      return false
    }
    let cyclic_parent = result.parents.copy()
    cyclic_parent[vertex] = Some(vertex)
    if accepts({
        origin: result.origin,
        distances: result.distances.copy(),
        parents: cyclic_parent,
      }) {
      return false
    }
  }
  accepts(result)
}

///|
test "quickcheck: certificates reject corrupted distances, reachability and parents" {
  @quickcheck.check(
    (input : (Int, Array[(Int, Int, Int)])) => {
      let n = 2 + (input.0 % 6).abs()
      let edges = input.1.map(e => Edge::{
        from: (e.0 % n).abs(),
        to: (e.1 % n).abs(),
        weight: (e.2 % 16).abs(),
      })
      // Every generated case has a reachable non-source vertex to corrupt.
      edges.push({ from: 0, to: 1, weight: (input.0 % 4).abs(), })
      let graph = try! Graph::from_array(edges, vertex_count=n)
      rejects_corruptions(graph, try! graph.bfs(0), false) &&
      rejects_corruptions(graph, try! graph.dijkstra(0), true)
    },
    count=500,
    max_size=48,
    max_shrinks=1000,
    seed=20260918,
  )
}
