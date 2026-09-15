///|
test "graph construction and traversal use core collection conventions" {
  let edges : Array[@graph.Edge] = [
    { from: 0, to: 1, weight: 5, },
    { from: 1, to: 2, weight: 2, },
  ]
  let graph = @graph.Graph::from_array(edges, vertex_count=4)
  let copied = @graph.Graph::from_iter(graph.iter(), vertex_count=4)
  assert_eq(copied.to_array(), edges)
  assert_eq(copied.vertex_count(), 4)
  assert_eq(copied.bfs(0).distance(2), Some(2))
  assert_eq(copied.dijkstra(0).distance(2), Some(7))
  assert_eq(copied.dijkstra(0).path_to(3), None)
  let empty = @graph.Graph::new(vertex_count=0)
  assert_eq(empty.iter().count(), 0)
  edges.clear()
  assert_eq(graph.iter().count(), 2)
}

///|
test "graph constructors and searches raise typed errors" {
  try @graph.Graph::new(vertex_count=-1) catch {
    @graph.NegativeVertexCount(n) => assert_eq(n, -1)
    _ => fail("unexpected graph error")
  } noraise {
    _ => fail("negative vertex count must raise")
  }
  let graph = @graph.Graph::new(vertex_count=1)
  try graph.bfs(1) catch {
    @graph.InvalidVertex(v) => assert_eq(v, 1)
    _ => fail("unexpected graph error")
  } noraise {
    _ => fail("invalid source must raise")
  }
}

///|
test "graph iterators preserve adjacency order and consume their input once" {
  let input : Array[@graph.Edge] = [
    { from: 1, to: 0, weight: 2, },
    { from: 0, to: 1, weight: 3, },
    { from: 1, to: 1, weight: 4, },
  ]
  let seen = []
  let graph = @graph.Graph::from_iter(
    input
    .iter()
    .map(e => {
      seen.push(e)
      e
    }),
    vertex_count=2,
  )
  assert_eq(seen, input)
  assert_eq(graph.to_array(), [input[1], input[0], input[2]])
  let first = graph.iter()
  let second = graph.iter()
  assert_eq(first.next(), Some(input[1]))
  assert_eq(second.to_array(), graph.to_array())
  assert_eq(first.to_array(), [input[0], input[2]])
  seen.clear()
  expect_graph_error(
    () => {
      @graph.Graph::from_iter(
        input
        .iter()
        .map(e => {
          seen.push(e)
          e
        }),
        vertex_count=-1,
      )
    },
    @graph.NegativeVertexCount(-1),
  )
  assert_true(seen.is_empty())
  expect_graph_error(
    () => @graph.Graph::from_iter(input.iter(), vertex_count=1),
    @graph.InvalidVertex(1),
  )
}
