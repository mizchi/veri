///|
test "Kruskal example treats edges as undirected and keeps disconnected components" {
  let forest = minimum_spanning_forest(
    [
      { from: 0, to: 1, weight: 7, },
      { from: 1, to: 0, weight: 1, },
      { from: 1, to: 2, weight: 2, },
      { from: 0, to: 2, weight: 5, },
      { from: 3, to: 3, weight: 0, },
    ],
    vertex_count=4,
  )
  assert_eq(forest.length(), 2)
  assert_eq(forest.fold(init=0, (sum, edge) => sum + edge.weight), 3)
}
