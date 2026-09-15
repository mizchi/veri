///|
/// A directed edge. Parallel edges and self-loops are retained.
#valtype
pub(all) struct Edge {
  from : Int
  to : Int
  weight : Int
} derive(Debug, Eq)

///|
pub(all) suberror GraphError {
  NegativeVertexCount(Int)
  InvalidVertex(Int)
  NegativeWeight(Int)
  DistanceOverflow(Int)
} derive(Debug, Eq)

///|
/// Immutable adjacency lists with vertices numbered 0..<vertex_count.
/// Algorithms are differential-tested; graph contains the separate proof model.
pub struct Graph {
  priv adjacency : Array[Array[Edge]]
}

///|
/// Construct a graph with the requested vertices and no edges.
pub fn Graph::new(vertex_count~ : Int) -> Graph raise GraphError {
  Graph::from_array([], vertex_count~)
}

///|
/// Validate endpoints and nonnegative weights, copying the input edges.
pub fn Graph::from_array(
  edges : ArrayView[Edge],
  vertex_count~ : Int,
) -> Graph raise GraphError {
  if vertex_count < 0 {
    raise NegativeVertexCount(vertex_count)
  }
  // Validate before allocating so malformed input does not trigger a large allocation.
  for e in edges {
    if e.from < 0 || e.from >= vertex_count {
      raise InvalidVertex(e.from)
    }
    if e.to < 0 || e.to >= vertex_count {
      raise InvalidVertex(e.to)
    }
    if e.weight < 0 {
      raise NegativeWeight(e.weight)
    }
  }
  let adjacency = Array::makei(vertex_count, _ => [])
  for e in edges {
    adjacency[e.from].push(e)
  }
  { adjacency, }
}

///|
/// Consume the iterator once and validate the resulting graph.
/// A negative vertex count is rejected before consuming any input.
pub fn Graph::from_iter(
  edges : Iter[Edge],
  vertex_count~ : Int,
) -> Graph raise GraphError {
  if vertex_count < 0 {
    raise NegativeVertexCount(vertex_count)
  }
  Graph::from_array(edges.to_array(), vertex_count~)
}

///|
pub fn Graph::vertex_count(self : Graph) -> Int {
  self.adjacency.length()
}

///|
/// A fresh edge array; modifying it cannot mutate the graph.
pub fn Graph::edges(self : Graph) -> Array[Edge] {
  self.to_array()
}

///|
/// Traverse edges in source-vertex order, retaining input order within each source.
/// Each call creates an independent iterator without an intermediate array.
pub fn Graph::iter(self : Graph) -> Iter[Edge] {
  self.adjacency.iter().flat_map(outgoing => outgoing.iter())
}

///|
/// Collect edges in iteration order into a fresh array.
pub fn Graph::to_array(self : Graph) -> Array[Edge] {
  self.iter().to_array()
}

///|
/// Minimum weight among parallel edges, or None for absent/invalid endpoints.
pub fn Graph::edge_weight(self : Graph, from : Int, to : Int) -> Int? {
  if from < 0 ||
    from >= self.vertex_count() ||
    to < 0 ||
    to >= self.vertex_count() {
    return None
  }
  let mut best : Int? = None
  for e in self.adjacency[from] {
    if e.to == to {
      match best {
        None => best = Some(e.weight)
        Some(old) => if e.weight < old { best = Some(e.weight) }
      }
    }
  }
  best
}

///|
/// Distances and predecessor witnesses owned by one search, with no mutable views.
pub struct SearchResult {
  priv origin : Int
  priv distances : Array[Int?]
  priv parents : Array[Int?]
}

///|
pub fn SearchResult::source(self : SearchResult) -> Int {
  self.origin
}

///|
/// Invalid or unreachable vertices return None. A Dijkstra result never contains
/// an unrepresentable reachable distance: the whole search returns DistanceOverflow.
pub fn SearchResult::distance(self : SearchResult, vertex : Int) -> Int? {
  if vertex < 0 || vertex >= self.distances.length() {
    None
  } else {
    self.distances[vertex]
  }
}

///|
/// A fresh source-to-target path, including both endpoints.
pub fn SearchResult::path_to(self : SearchResult, target : Int) -> Array[Int]? {
  if self.distance(target) is None {
    return None
  }
  let path = []
  let mut vertex = target
  // A bound also makes this safe for the internal certificate rejection tests.
  for _i = 0; _i < self.distances.length(); _i = _i + 1 {
    path.push(vertex)
    if vertex == self.origin {
      return Some(path.rev())
    }
    match self.parents[vertex] {
      Some(parent) => {
        if parent < 0 || parent >= self.distances.length() {
          return None
        }
        vertex = parent
      }
      None => return None
    }
  }
  None
}

///|
/// O(V+E) shortest edge counts, ignoring weights, using runtime/queue.
pub fn Graph::bfs(self : Graph, source : Int) -> SearchResult raise GraphError {
  let n = self.vertex_count()
  if source < 0 || source >= n {
    raise InvalidVertex(source)
  }
  let distances : Array[Int?] = Array::make(n, None)
  let parents : Array[Int?] = Array::make(n, None)
  distances[source] = Some(0)
  let mut frontier = @queue.Queue::new().push(source)
  while frontier.pop() is Some((vertex, rest)) {
    frontier = rest
    let cost = distances[vertex].unwrap()
    for e in self.adjacency[vertex] {
      if distances[e.to] is None {
        // Every discovered vertex has a simple path of at most n-1 edges.
        distances[e.to] = Some(cost + 1)
        parents[e.to] = Some(vertex)
        frontier = frontier.push(e.to)
      }
    }
  }
  { origin: source, distances, parents, }
}

///|
/// Dijkstra using runtime/pqueue for distances and FIFO buckets for equal keys.
/// O((V+E) log(E+1)) amortized time, O(V+E) space. Zero weights are allowed.
/// Overflowing detours are skipped. Error only if a reachable vertex's minimum
/// cost cannot fit in Int; a representable alternative is never rejected.
pub fn Graph::dijkstra(
  self : Graph,
  source : Int,
) -> SearchResult raise GraphError {
  let n = self.vertex_count()
  if source < 0 || source >= n {
    raise InvalidVertex(source)
  }
  let distances : Array[Int?] = Array::make(n, None)
  let parents : Array[Int?] = Array::make(n, None)
  let buckets : Map[Int, @queue.Queue[Int]] = Map([])
  let mut priorities = @pqueue.IntMinQueue::new().push(0)
  buckets[0] = @queue.Queue::new().push(source)
  distances[source] = Some(0)
  while priorities.pop() is Some((cost, remaining)) {
    priorities = remaining
    let (vertex, rest) = buckets[cost].pop().unwrap()
    if rest.is_empty() {
      buckets.remove(cost)
    } else {
      buckets[cost] = rest
    }
    if distances[vertex] != Some(cost) {
      continue
    }
    for e in self.adjacency[vertex] {
      match @int32.checked_add(cost, e.weight) {
        None => ()
        Some(candidate) => {
          let improve = match distances[e.to] {
            None => true
            Some(old) => candidate < old
          }
          if improve {
            distances[e.to] = Some(candidate)
            parents[e.to] = Some(vertex)
            let bucket = buckets.get(candidate)
            buckets[candidate] = bucket
              .unwrap_or(@queue.Queue::new())
              .push(e.to)
            priorities = priorities.push(candidate)
          }
        }
      }
    }
  }
  let reached = self.bfs(source)
  for vertex = 0; vertex < n; vertex = vertex + 1 {
    if reached.distance(vertex) is Some(_) && distances[vertex] is None {
      raise DistanceOverflow(vertex)
    }
  }
  { origin: source, distances, parents, }
}
