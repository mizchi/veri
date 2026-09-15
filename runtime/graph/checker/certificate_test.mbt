///|
test "complete checker accepts paths, parallel edges, zero weights and Int max" {
  let edges : FixedArray[@checker.Edge] = [
    { from: 0, to: 1, weight: 2147483647, },
    { from: 0, to: 1, weight: 0, },
    { from: 1, to: 2, weight: 2147483647, },
  ]
  let parents : FixedArray[Int?] = [None, Some(0), Some(1), None]
  assert_true(
    @checker.check_certificate(
      4,
      edges,
      [Some(0), Some(0), Some(2147483647), None],
      parents,
      0,
      true,
    ),
  )
  assert_true(
    @checker.check_certificate(
      4,
      edges,
      [Some(0), Some(1), Some(2), None],
      parents,
      0,
      false,
    ),
  )
  assert_false(
    @checker.check_certificate(
      4,
      edges,
      [Some(0), Some(0), Some(2147483646), None],
      parents,
      0,
      true,
    ),
  )
  assert_false(
    @checker.check_certificate(
      4,
      edges,
      [Some(0), Some(1), Some(3), None],
      parents,
      0,
      false,
    ),
  )
}

///|
test "complete checker is total on malformed raw certificates and graphs" {
  assert_false(@checker.check_certificate(0, [], [], [], 0, false))
  assert_false(@checker.check_certificate(-1, [], [], [], 0, true))
  assert_false(@checker.check_certificate(1, [], [Some(0)], [], 0, true))
  assert_false(@checker.check_certificate(1, [], [Some(0)], [None], -1, true))
  assert_false(@checker.check_certificate(1, [], [Some(0)], [None], 1, true))
  assert_false(@checker.check_certificate(1, [], [Some(1)], [None], 0, true))
  assert_false(@checker.check_certificate(1, [], [Some(0)], [Some(0)], 0, true))
  for
    edge in [
      @checker.Edge::{ from: -1, to: 0, weight: 0, },
      { from: 0, to: 1, weight: 0, },
      { from: 0, to: 0, weight: -1, },
    ] {
    assert_false(
      @checker.check_certificate(1, [edge], [Some(0)], [None], 0, false),
    )
  }
  assert_false(
    @checker.check_certificate(2, [], [Some(0), None], [None, Some(0)], 0, true),
  )
  assert_false(
    @checker.check_certificate(
      2,
      [],
      [Some(0), Some(0)],
      [None, Some(9)],
      0,
      true,
    ),
  )
}

///|
test "complete checker rejects zero cycles, hidden reachability and nonminimum witnesses" {
  let cycle : FixedArray[@checker.Edge] = [
    { from: 1, to: 2, weight: 0, },
    { from: 2, to: 1, weight: 0, },
  ]
  assert_false(
    @checker.check_certificate(
      3,
      cycle,
      [Some(0), Some(0), Some(0)],
      [None, Some(2), Some(1)],
      0,
      true,
    ),
  )
  assert_true(
    @checker.check_certificate(
      3,
      cycle,
      [Some(0), None, None],
      [None, None, None],
      0,
      true,
    ),
  )
  let edges : FixedArray[@checker.Edge] = [
    { from: 0, to: 1, weight: 1, },
    { from: 0, to: 2, weight: 10, },
    { from: 1, to: 2, weight: 1, },
  ]
  assert_false(
    @checker.check_certificate(
      3,
      edges,
      [Some(0), Some(1), None],
      [None, Some(0), None],
      0,
      true,
    ),
  )
  assert_false(
    @checker.check_certificate(
      3,
      edges,
      [Some(0), Some(1), Some(10)],
      [None, Some(0), Some(0)],
      0,
      true,
    ),
  )
}
