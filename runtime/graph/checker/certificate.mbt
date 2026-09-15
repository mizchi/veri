///|
using @list {type List}

///|
/// A directed edge. Parallel edges and self-loops are retained.
#valtype
pub(all) struct Edge {
  from : Int
  to : Int
  weight : Int
} derive(Debug, Eq)

///|
fn check_edges(
  n : Int,
  edges : FixedArray[Edge],
) -> Bool where {
  proof_ensure: result => result == edges_valid(n, edges, edges.length()),
} {
  let mut result = true
  for i = 0; i < edges.length(); i = i + 1 {
    let edge = edges[i]
    if edge.from < 0 ||
      edge.from >= n ||
      edge.to < 0 ||
      edge.to >= n ||
      edge.weight < 0 {
      result = false
    }
  } where {
    proof_invariant: 0 <= i && i <= edges.length(),
    proof_invariant: result == edges_valid(n, edges, i),
  }
  result
}

///|
fn check_ancestors(
  ps : FixedArray[Int?],
  source : Int,
  vertex : Int,
  fuel : Int,
) -> Bool where {
  proof_require: 0 <= fuel,
  proof_ensure: result => result → anchored(ps, source, vertex),
  proof_decrease: fuel_size(fuel),
} {
  if vertex == source {
    true
  } else if fuel == 0 || vertex < 0 || vertex >= ps.length() {
    false
  } else {
    match ps[vertex] {
      None => false
      Some(parent) => check_ancestors(ps, source, parent, fuel - 1)
    }
  }
}

///|
fn check_tight(
  edges : FixedArray[Edge],
  ds : FixedArray[Int?],
  parent : Int,
  vertex : Int,
  weighted : Bool,
) -> Bool where {
  proof_require: labeled(ds, parent) && labeled(ds, vertex),
  proof_require: @integer.le(@integer.zero(), distance(ds, parent)),
  proof_require: @integer.le(@integer.zero(), distance(ds, vertex)),
  proof_require: edges_valid(ds.length(), edges, edges.length()),
  proof_ensure: result => {
    result == tight_prefix(edges, ds, parent, vertex, weighted, edges.length())
  },
} {
  let mut result = false
  match (ds[parent], ds[vertex]) {
    (Some(before), Some(after)) =>
      for i = 0; i < edges.length(); i = i + 1 {
        let edge = edges[i]
        let weight = if weighted { edge.weight } else { 1 }
        if edge.from == parent &&
          edge.to == vertex &&
          before >= 0 &&
          after >= before &&
          after - before == weight {
          result = true
        }
      } where {
        proof_invariant: 0 <= i && i <= edges.length(),
        proof_invariant: result ==
        tight_prefix(edges, ds, parent, vertex, weighted, i),
      }
    _ => ()
  }
  result
}

///|
fn check_vertex(
  edges : FixedArray[Edge],
  ds : FixedArray[Int?],
  ps : FixedArray[Int?],
  source : Int,
  vertex : Int,
  weighted : Bool,
) -> Bool where {
  proof_require: 0 <= vertex &&
  vertex < ds.length() &&
  ps.length() == ds.length(),
  proof_require: edges_valid(ds.length(), edges, edges.length()),
  proof_ensure: result => {
    result → vertex_valid(edges, ds, ps, source, vertex, weighted)
  },
} {
  match ds[vertex] {
    None =>
      match ps[vertex] {
        None => true
        Some(_) => false
      }
    Some(cost) =>
      if cost < 0 {
        false
      } else if vertex == source {
        true
      } else {
        match ps[vertex] {
          None => false
          Some(parent) =>
            if parent < 0 || parent >= ds.length() {
              false
            } else {
              match ds[parent] {
                None => false
                Some(before) =>
                  before >= 0 &&
                  check_tight(edges, ds, parent, vertex, weighted) &&
                  check_ancestors(ps, source, vertex, ds.length())
              }
            }
        }
      }
  }
}

///|
fn check_feasible(
  edges : FixedArray[Edge],
  ds : FixedArray[Int?],
  weighted : Bool,
) -> Bool where {
  proof_require: edges_valid(ds.length(), edges, edges.length()),
  proof_ensure: result => {
    result → feasible_prefix(edges, ds, weighted, edges.length())
  },
} {
  let mut result = true
  for i = 0; i < edges.length(); i = i + 1 {
    let edge = edges[i]
    match ds[edge.from] {
      None => ()
      Some(cost) =>
        match ds[edge.to] {
          None => result = false
          Some(next) => {
            let weight = if weighted { edge.weight } else { 1 }
            if !relaxation(cost, next, weight) {
              result = false
            }
          }
        }
    }
  } where {
    proof_invariant: 0 <= i && i <= edges.length(),
    proof_invariant: result → feasible_prefix(edges, ds, weighted, i),
  }
  result
}

///|
/// Validate an untrusted shortest-path certificate without mutating its arrays.
/// All endpoints, weights, lengths and labels are checked; no input preconditions.
pub fn check_certificate(
  n : Int,
  edges : FixedArray[Edge],
  ds : FixedArray[Int?],
  ps : FixedArray[Int?],
  source : Int,
  weighted : Bool,
) -> Bool where {
  proof_ensure: result => result → correct(n, edges, ds, ps, source, weighted),
} {
  if source < 0 || source >= n || ds.length() != n || ps.length() != n {
    false
  } else if !check_root(ds[source], ps[source]) || !check_edges(n, edges) {
    false
  } else {
    let mut result = true
    for vertex = 0; vertex < n; vertex = vertex + 1 {
      if !check_vertex(edges, ds, ps, source, vertex, weighted) {
        result = false
      }
    } where {
      proof_invariant: 0 <= vertex && vertex <= n,
      proof_invariant: result →
      vertices_valid(edges, ds, ps, source, weighted, vertex),
    }
    result && check_feasible(edges, ds, weighted)
  }
}

///|
fn check_root(
  cost : Int?,
  parent : Int?,
) -> Bool where {
  proof_ensure: result => result == (has_value(cost, 0) && absent(parent)),
} {
  match (cost, parent) {
    (Some(value), None) => value == 0
    _ => false
  }
}
