///|
test "verified topological checker validates permutation and every edge" {
  let edges : FixedArray[@checker.Edge] = [
    { from: 0, to: 1, weight: 0, },
    { from: 1, to: 2, weight: 1, },
  ]
  assert_true(@topology.check_topological_order(4, edges, [0, 1, 2, 3]))
  assert_true(@topology.check_topological_order(4, edges, [3, 0, 1, 2]))
  assert_false(@topology.check_topological_order(4, edges, [0, 1, 1, 2]))
  assert_false(@topology.check_topological_order(4, edges, [2, 1, 0, 3]))
  assert_false(@topology.check_topological_order(4, edges, [0, 1, 2, 4]))
  assert_false(@topology.check_topological_order(4, edges, [0, 1, 2]))
  assert_true(@topology.check_topological_order(0, [], []))
  assert_false(@topology.check_topological_order(-1, [], []))
  assert_false(@topology.check_topological_order(-2147483648, [], []))
  assert_true(
    @topology.check_topological_order(
      2,
      [{ from: 0, to: 1, weight: -2147483648, }],
      [0, 1],
    ),
  )
  assert_false(
    @topology.check_topological_order(1, [{ from: 0, to: 1, weight: 0, }], [0]),
  )
  assert_false(
    @topology.check_topological_order(1, [{ from: 0, to: 0, weight: 0, }], [0]),
  )
}

///|
test "verified cycle checker checks closure, simplicity and actual edges" {
  let edges : FixedArray[@checker.Edge] = [
    { from: 0, to: 1, weight: 9, },
    { from: 1, to: 2, weight: 0, },
    { from: 2, to: 0, weight: 7, },
  ]
  let starts : FixedArray[Int] = [0, 1, 2, 3]
  assert_true(@topology.check_cycle(edges, starts, [0, 1, 2, 0]))
  assert_true(@topology.check_cycle(edges, starts, [1, 2, 0, 1]))
  assert_false(@topology.check_cycle(edges, starts, [0, 2, 1, 0]))
  assert_false(@topology.check_cycle(edges, starts, [0, 1, 2]))
  assert_false(@topology.check_cycle(edges, starts, [0, 1, 2, 0, 1, 2, 0]))
  assert_false(@topology.check_cycle(edges, starts, [3, 3]))
  assert_false(@topology.check_cycle(edges, starts, [-1, -1]))
  assert_false(@topology.check_cycle(edges, starts, [4, 4]))
  assert_false(@topology.check_cycle(edges, starts, [0]))
  assert_false(@topology.check_cycle(edges, starts, []))
  assert_true(
    @topology.check_cycle([{ from: 0, to: 0, weight: 0, }], [0], [0, 0]),
  )
  assert_false(@topology.check_cycle([], [], []))
  assert_false(@topology.check_cycle(edges, [-1, 1, 2], [0, 1, 2, 0]))
  assert_false(@topology.check_cycle(edges, [0, 99, 2], [0, 1, 2, 0]))
  assert_false(@topology.check_cycle([], [2147483647], [0, 0]))
  assert_false(@topology.check_cycle(edges, [-2147483648, 1, 2], [0, 1, 2, 0]))
}
