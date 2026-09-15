///|
/// Check BFS labels and predecessors against the graph's actual stored edges.
/// The checker has no certificate preconditions and does not call BFS.
pub fn Graph::check_bfs(
  self : Graph,
  search : SearchResult,
) -> Bool where {
  proof_ensure: accepted => accepted → certified(self, search, false),
} {
  @checker.check_certificate(
    self.starts.length(),
    self.edge_data,
    search.distances,
    search.parents,
    search.origin,
    false,
  )
}

///|
/// Check Dijkstra labels and predecessors, including zero weights and parallel edges.
/// Uses mathematical path costs in the contract, without overflowing runtime sums.
pub fn Graph::check_dijkstra(
  self : Graph,
  search : SearchResult,
) -> Bool where {
  proof_ensure: accepted => accepted → certified(self, search, true),
} {
  @checker.check_certificate(
    self.starts.length(),
    self.edge_data,
    search.distances,
    search.parents,
    search.origin,
    true,
  )
}
