///|
fn check_ranks(
  order : FixedArray[Int],
  ranks : FixedArray[Int],
) -> Bool where {
  proof_ensure: accepted => {
    accepted → rank_entries(order, ranks, ranks.length())
  },
} {
  let mut accepted = true
  for vertex = 0; vertex < ranks.length(); vertex = vertex + 1 {
    let index = ranks[vertex]
    if index < 0 || index >= order.length() {
      accepted = false
    } else if order[index] != vertex {
      accepted = false
    }
  } where {
    proof_invariant: 0 <= vertex && vertex <= ranks.length(),
    proof_invariant: accepted → rank_entries(order, ranks, vertex),
  }
  accepted
}

///|
fn check_ranked_edges(
  edges : FixedArray[@checker.Edge],
  ranks : FixedArray[Int],
) -> Bool where {
  proof_ensure: accepted => {
    accepted → ranked_edges(ranks, edges, edges.length())
  },
} {
  let mut accepted = true
  for i = 0; i < edges.length(); i = i + 1 {
    let edge = edges[i]
    if edge.from < 0 ||
      edge.from >= ranks.length() ||
      edge.to < 0 ||
      edge.to >= ranks.length() {
      accepted = false
    } else if ranks[edge.from] >= ranks[edge.to] {
      accepted = false
    }
  } where {
    proof_invariant: 0 <= i && i <= edges.length(),
    proof_invariant: accepted → ranked_edges(ranks, edges, i),
  }
  accepted
}

///|
/// Validate a topological permutation against the actual edges. No preconditions.
/// O(V+E) time and O(V) auxiliary space; weights are irrelevant.
pub fn check_topological_order(
  n : Int,
  edges : FixedArray[@checker.Edge],
  order : FixedArray[Int],
) -> Bool where {
  proof_ensure: accepted => accepted → topological(n, edges, order),
  proof_ensure: accepted => accepted → acyclic(edges),
} {
  if n < 0 || order.length() != n {
    false
  } else {
    let ranks = FixedArray::make(n, -1)
    let mut accepted = true
    for i = 0; i < n; i = i + 1 {
      if accepted {
        let vertex = order[i]
        if vertex < 0 || vertex >= n {
          accepted = false
        } else if ranks[vertex] != -1 {
          accepted = false
        } else {
          ranks[vertex] = i
        }
      }
    } where {
      proof_invariant: 0 <= i && i <= n,
      proof_invariant: accepted → inverse_prefix(order, ranks, i),
    }
    accepted && check_ranks(order, ranks) && check_ranked_edges(edges, ranks)
  }
}
