///|
test "BFS counts edges; Dijkstra minimizes nonnegative weights" {
  let g = @graph.Graph::from_array(
    [
      { from: 0, to: 1, weight: 10, },
      { from: 0, to: 2, weight: 1, },
      { from: 2, to: 1, weight: 1, },
      { from: 1, to: 3, weight: 0, },
      { from: 3, to: 1, weight: 0, },
      { from: 0, to: 1, weight: 7, },
      { from: 0, to: 0, weight: 0, },
    ],
    vertex_count=5,
  )
  let bfs = g.bfs(0)
  let shortest = g.dijkstra(0)
  assert_eq(bfs.distance(1), Some(1))
  assert_eq(bfs.distance(3), Some(2))
  assert_eq(shortest.distance(3), Some(2))
  assert_eq(shortest.path_to(3), Some([0, 2, 1, 3]))
  assert_eq(shortest.path_to(0), Some([0]))
  assert_eq(shortest.path_to(4), None)
  assert_eq(shortest.path_to(-1), None)
  assert_true(g.check_bfs(bfs))
  assert_true(g.check_dijkstra(shortest))
}

///|
fn[T] expect_graph_error(
  action : () -> T raise @graph.GraphError,
  expected : @graph.GraphError,
) -> Unit raise {
  try action() catch {
    error => assert_eq(error, expected)
  } noraise {
    _ => fail("expected a graph error")
  }
}

///|
test "invalid inputs, empty graphs and detached arrays" {
  expect_graph_error(
    () => @graph.Graph::from_array([], vertex_count=-1),
    @graph.NegativeVertexCount(-1),
  )
  expect_graph_error(
    () => {
      @graph.Graph::from_array([{ from: 0, to: 1, weight: 0, }], vertex_count=1)
    },
    @graph.InvalidVertex(1),
  )
  expect_graph_error(
    () => {
      @graph.Graph::from_array(
        [{ from: -1, to: 0, weight: 0, }],
        vertex_count=1,
      )
    },
    @graph.InvalidVertex(-1),
  )
  expect_graph_error(
    () => {
      @graph.Graph::from_array(
        [{ from: 0, to: 0, weight: -1, }],
        vertex_count=1,
      )
    },
    @graph.NegativeWeight(-1),
  )
  let empty = @graph.Graph::from_array([], vertex_count=0)
  assert_eq(empty.vertex_count(), 0)
  expect_graph_error(() => empty.bfs(0), @graph.InvalidVertex(0))
  expect_graph_error(() => empty.dijkstra(-1), @graph.InvalidVertex(-1))
  let edges : Array[@graph.Edge] = [{ from: 0, to: 1, weight: 3, }]
  let g = @graph.Graph::from_array(edges, vertex_count=2)
  edges.clear()
  g.edges().clear()
  assert_eq(g.edge_weight(0, 1), Some(3))
  let result = g.dijkstra(0)
  result.path_to(1).unwrap().clear()
  assert_eq(result.path_to(1), Some([0, 1]))
  assert_eq(result.source(), 0)
  assert_eq(result.distance(2), None)
}

///|
test "overflowing detours do not hide representable shortest paths" {
  let edges : Array[@graph.Edge] = [
    { from: 0, to: 1, weight: 2147483647, },
    { from: 1, to: 2, weight: 1, },
  ]
  let overflow = @graph.Graph::from_array(edges, vertex_count=3)
  expect_graph_error(() => overflow.dijkstra(0), @graph.DistanceOverflow(2))
  edges.push({ from: 0, to: 2, weight: 3, })
  let g = @graph.Graph::from_array(edges, vertex_count=3)
  let result = g.dijkstra(0)
  assert_eq(result.distance(1), Some(2147483647))
  assert_eq(result.distance(2), Some(3))
  assert_true(g.check_dijkstra(result))
  let other_source = g.dijkstra(2)
  assert_eq(other_source.distance(0), None)
}
