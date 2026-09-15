///|
test "checked sizes, binary headers and shortest routes" {
  assert_eq(@toolkit.allocation_size(10, 4, 6), Some(46))
  assert_eq(@toolkit.allocation_size(2147483647, 2, 0), None)
  assert_eq(@toolkit.allocation_size(1, 2147483647, 1), None)
  assert_eq(
    @toolkit.read_header(b"\x00\x02\x00\x00\x00\x10"[:], 0),
    Some((UInt16(2), 16U, 6)),
  )
  assert_eq(@toolkit.read_header(b"\x00\x02\x00\x00\x00"[:], 0), None)
  assert_eq(@toolkit.length_as_int(4294967295U), None)
  assert_eq(
    @toolkit.route(
      [{ from: 0, to: 1, weight: 2, }, { from: 1, to: 2, weight: 3, }],
      3,
      0,
      2,
    ),
    Some([0, 1, 2]),
  )
}
