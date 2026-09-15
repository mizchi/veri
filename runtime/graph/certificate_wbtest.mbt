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
