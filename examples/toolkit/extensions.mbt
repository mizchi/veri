///|
/// A caller can validate untrusted order once, then call the proved binary search.
pub fn insertion_index(
  values : FixedArray[Int],
  key : Int,
) -> Int? where {
  proof_ensure: result => {
    match result {
      None => @search.ordered(values) == false
      Some(index) => @search.lower_partition(values, key, index)
    }
  },
} {
  if @search.is_sorted(values) {
    Some(@search.lower_bound(values, key))
  } else {
    None
  }
}

///|
test "core containers, dependency ordering, components and parsing compose" {
  let names : @map.Map[Int, String] = Map([
    (0, "parse"),
    (1, "compile"),
    (2, "link"),
  ])
  let ready : @set.Set[Int] = Set([0])
  assert_eq(names.get(0), Some("parse"))
  assert_true(ready.contains(0))
  let graph = @graph.Graph::from_array(
    [{ from: 0, to: 1, weight: 1, }, { from: 1, to: 2, weight: 1, }],
    vertex_count=3,
  )
  match graph.topological_sort() {
    Ordered(order) => assert_true(graph.check_topological_order(order))
    Cyclic(_) => fail("dependency graph is acyclic")
  }
  let components = @union_find.UnionFind::new(3)
  for edge in graph.iter() {
    ignore(components.union(edge.from, edge.to))
  }
  assert_eq(components.component_count(), 1)
  assert_eq(insertion_index([1, 2, 2, 4], 2), Some(1))
  assert_eq(insertion_index([2, 1], 1), None)
  let data : Bytes = b"\x00\x00\x00\x02ok"
  let (payload, rest) = @cursor.Cursor::new(data[:])
    .read(@cursor.length_prefixed_uint_be())
    .unwrap()
  assert_eq(payload.to_owned(), b"ok")
  assert_eq(rest.remaining(), 0)
}
