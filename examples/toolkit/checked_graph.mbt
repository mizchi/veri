///|
/// A client can consume the public checker's proof for any queried vertex.
pub fn certify_bfs_at(
  graph : @graph.Graph,
  search : @graph.SearchResult,
  vertex : Int,
) -> Bool where {
  proof_ensure: accepted => {
    accepted → @graph.shortest_at(graph, search, vertex, false)
  },
} {
  graph.check_bfs(search)
}

///|
/// Weighted costs are mathematical sums, even when detours exceed Int max.
pub fn certify_dijkstra_at(
  graph : @graph.Graph,
  search : @graph.SearchResult,
  vertex : Int,
) -> Bool where {
  proof_ensure: accepted => {
    accepted → @graph.shortest_at(graph, search, vertex, true)
  },
} {
  graph.check_dijkstra(search)
}

///|
/// A topological permutation certifies the entire graph has no directed cycles.
pub fn certify_acyclic(
  graph : @graph.Graph,
  order : FixedArray[Int],
) -> Bool where {
  proof_ensure: accepted => accepted → @graph.acyclic(graph),
} {
  graph.check_topological_order(order)
}

///|
/// A closed simple witness certifies the opposite verdict.
pub fn certify_cyclic(
  graph : @graph.Graph,
  cycle : FixedArray[Int],
) -> Bool where {
  proof_ensure: accepted => accepted → @graph.cyclic(graph),
  proof_ensure: accepted => accepted → !@graph.acyclic(graph),
} {
  graph.check_cycle(cycle)
}

///|
/// The producer is untrusted; its Ordered/Cyclic result is checked before use.
pub fn certify_topology(
  graph : @graph.Graph,
  topology : @graph.Topology,
) -> Bool where {
  proof_ensure: accepted => accepted → @graph.valid_topology(graph, topology),
} {
  graph.check_topology(topology)
}
