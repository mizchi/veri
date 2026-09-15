///|
/// Independently check path witnesses, reachable-set closure and edge relaxation.
/// This executable checker is tested; graph.optimality_certificate is its logical
/// foundation, not a proof of this mutable implementation or of native casts.
fn Graph::check(self : Graph, result : SearchResult, weighted : Bool) -> Bool {
  let n = self.vertex_count()
  let source = result.origin
  if source < 0 ||
    source >= n ||
    result.distances.length() != n ||
    result.parents.length() != n {
    return false
  }
  if result.distances[source] != Some(0) || result.parents[source] != None {
    return false
  }
  for vertex = 0; vertex < n; vertex = vertex + 1 {
    match result.distances[vertex] {
      None => if result.parents[vertex] != None { return false }
      Some(cost) => {
        if cost < 0 {
          return false
        }
        let path = match result.path_to(vertex) {
          None => return false
          Some(path) => path
        }
        let mut total = 0
        for i = 1; i < path.length(); i = i + 1 {
          let weight = match self.edge_weight(path[i - 1], path[i]) {
            None => return false
            Some(w) => if weighted { w } else { 1 }
          }
          total = match @int32.checked_add(total, weight) {
            None => return false
            Some(value) => value
          }
        }
        if total != cost {
          return false
        }
        for edge in self.adjacency[vertex] {
          let next = match result.distances[edge.to] {
            None => return false
            Some(next) => next
          }
          let weight = if weighted { edge.weight } else { 1 }
          match @int32.checked_add(cost, weight) {
            // Both operands are nonnegative, so overflow means every Int next is <= sum.
            None => ()
            Some(bound) => if next > bound { return false }
          }
        }
      }
    }
  }
  true
}

///|
/// Validate a BFS result against this graph, including unreachability claims.
pub fn Graph::check_bfs(self : Graph, result : SearchResult) -> Bool {
  self.check(result, false)
}

///|
/// Validate a weighted shortest-path result against this graph.
pub fn Graph::check_dijkstra(self : Graph, result : SearchResult) -> Bool {
  self.check(result, true)
}
