///|
/// Example: minimum spanning forest of an undirected nonnegative-weight graph.
/// Each Edge is interpreted as an undirected connection. Self-loops are ignored.
/// Uses core sorting and UnionFind; this example is tested, not formally proved.
pub fn minimum_spanning_forest(
  edges : ArrayView[@graph.Edge],
  vertex_count~ : Int,
) -> Array[@graph.Edge] raise {
  let validated = @graph.Graph::from_array(edges, vertex_count~)
  let sorted = validated.to_array()
  sorted.sort_by((a, b) => a.weight.compare(b.weight))
  let components = @union_find.UnionFind::new(vertex_count)
  let result : Array[@graph.Edge] = []
  for edge in sorted {
    if components.union(edge.from, edge.to) {
      result.push(edge)
    }
  }
  result
}
