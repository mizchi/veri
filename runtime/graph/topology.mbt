///|
/// Either a permutation in dependency order, or a simple directed cycle with
/// its first vertex repeated at the end. Empty graphs yield Ordered([]).
pub(all) enum Topology {
  Ordered(FixedArray[Int])
  Cyclic(FixedArray[Int])
} derive(Debug, Eq)

///|
/// Iterative DFS: O(V+E) time and O(V) auxiliary space, including long chains.
/// Weights are ignored. The DFS producer is differential-tested; check_topology
/// validates its actual returned arrays using proved checkers.
pub fn Graph::topological_sort(self : Graph) -> Topology {
  let n = self.vertex_count()
  let color = Array::make(n, 0)
  let next_edge = Array::make(n, 0)
  let active_position = Array::make(n, -1)
  let active : Array[Int] = []
  let finished : Array[Int] = []
  for start = 0; start < n; start = start + 1 {
    if color[start] != 0 {
      continue
    }
    color[start] = 1
    active_position[start] = 0
    active.push(start)
    while !active.is_empty() {
      let vertex = active[active.length() - 1]
      if next_edge[vertex] == self.outgoing(vertex).length() {
        ignore(active.pop())
        color[vertex] = 2
        finished.push(vertex)
      } else {
        let target = self.outgoing(vertex)[next_edge[vertex]].to
        next_edge[vertex] += 1
        if color[target] == 1 {
          let cycle = active[active_position[target]:].to_owned()
          cycle.push(target)
          return Cyclic(FixedArray::from_array(cycle))
        }
        if color[target] == 0 {
          color[target] = 1
          active_position[target] = active.length()
          active.push(target)
        }
      }
    }
  }
  Ordered(FixedArray::from_array(finished.rev()))
}

///|
/// Validate a permutation against every stored edge and certify acyclicity.
/// O(V+E) time and O(V) space; does not call topological_sort.
pub fn Graph::check_topological_order(
  self : Graph,
  order : FixedArray[Int],
) -> Bool where {
  proof_ensure: accepted => accepted → topological_order(self, order),
  proof_ensure: accepted => accepted → acyclic(self),
} {
  @topology_checker.check_topological_order(
    self.starts.length(),
    self.edge_data,
    order,
  )
}

///|
/// Validate a nonempty simple directed cycle, including its repeated final vertex.
/// O(V+E) time and O(V) space with this graph's CSR storage. Self-loops are [v,v].
pub fn Graph::check_cycle(
  self : Graph,
  cycle : FixedArray[Int],
) -> Bool where {
  proof_ensure: accepted => accepted → simple_cycle(self, cycle),
  proof_ensure: accepted => accepted → cyclic(self),
  proof_ensure: accepted => accepted → !acyclic(self),
} {
  @topology_checker.check_cycle(self.edge_data, self.starts, cycle)
}

///|
/// Check either variant directly; acceptance certifies its witnesses and verdict.
pub fn Graph::check_topology(
  self : Graph,
  topology : Topology,
) -> Bool where {
  proof_ensure: accepted => accepted → valid_topology(self, topology),
} {
  match topology {
    Ordered(order) => self.check_topological_order(order)
    Cyclic(cycle) => self.check_cycle(cycle)
  }
}

///|
/// Convenience adapter for an ArrayView. Copies the view before checking.
/// The copy is differential-tested; use the FixedArray API in verified code.
pub fn Graph::check_topological_order_view(
  self : Graph,
  order : ArrayView[Int],
) -> Bool {
  self.check_topological_order(FixedArray::from_array(order))
}

///|
/// Convenience adapter for an ArrayView. Copies the view before checking.
/// The copy is differential-tested; use the FixedArray API in verified code.
pub fn Graph::check_cycle_view(self : Graph, cycle : ArrayView[Int]) -> Bool {
  self.check_cycle(FixedArray::from_array(cycle))
}
