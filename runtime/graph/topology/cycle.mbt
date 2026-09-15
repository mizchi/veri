///|
/// CSR offsets only narrow the search. Check the range and the actual endpoints,
/// so malformed offsets cannot fabricate an edge or cause an invalid read.
fn check_edge(
  edges : FixedArray[@checker.Edge],
  starts : FixedArray[Int],
  source : Int,
  target : Int,
) -> Bool where {
  proof_require: vertex_index(starts.length(), source),
  proof_ensure: found => found → edge_exists(edges, source, target),
} {
  let start = starts[source]
  let stop = if source + 1 < starts.length() {
    starts[source + 1]
  } else {
    edges.length()
  }
  if start < 0 || stop < start || stop > edges.length() {
    false
  } else {
    let mut found = false
    for i = start; i < stop; i = i + 1 {
      let edge = edges[i]
      if edge.from == source && edge.to == target {
        found = true
      }
    } where {
      proof_invariant: start <= i && i <= stop,
      proof_invariant: found → edge_exists(edges, source, target),
    }
    found
  }
}

///|
/// Validate a simple cycle over the actual edge storage; no input preconditions.
/// The number of vertices is starts.length(). For CSR input, O(V+E) time and O(V)
/// space: no source vertex is visited twice. Edge weights are irrelevant.
pub fn check_cycle(
  edges : FixedArray[@checker.Edge],
  starts : FixedArray[Int],
  cycle : FixedArray[Int],
) -> Bool where {
  proof_ensure: accepted => {
    accepted → simple_cycle(starts.length(), edges, cycle)
  },
  proof_ensure: accepted => accepted → has_cycle(edges),
  proof_ensure: accepted => accepted → !acyclic(edges),
} {
  if cycle.length() < 2 {
    false
  } else if cycle.length() - 1 > starts.length() {
    // A simple cycle visits at most V vertices, excluding the repeated endpoint.
    false
  } else if cycle[0] != cycle[cycle.length() - 1] {
    false
  } else {
    let n = starts.length()
    let seen = FixedArray::make(n, false)
    let mut accepted = true
    for i = 0; i < cycle.length() - 1; i = i + 1 {
      if accepted {
        let source = cycle[i]
        let target = cycle[i + 1]
        if source < 0 || source >= n || target < 0 || target >= n {
          accepted = false
        } else if seen[source] || !check_edge(edges, starts, source, target) {
          accepted = false
        } else {
          seen[source] = true
        }
      }
    } where {
      proof_invariant: 0 <= i && i < cycle.length(),
      proof_invariant: accepted → unique_prefix(cycle, i),
      proof_invariant: accepted → seen_prefix(seen, cycle, i),
      proof_invariant: accepted → links_prefix(n, edges, cycle, i),
    }
    accepted
  }
}
