///|
test "runtime bridges imported from another module" {
  assert_eq(@bridges.zero_after_max(), 0U)
  assert_eq(@bridges.first_or([42, 10], -1), 42)
  assert_eq(@bridges.first_or(FixedArray::make(0, 0), -1), -1)
}

///|
test "contracts compose across a wrap in either width" {
  assert_eq(@bridges.restore32(0xffffffffU, 1U), 0xffffffffU)
  assert_eq(@bridges.restore32(1U, 0xffffffffU), 1U)
  assert_eq(@bridges.restore64(0xffffffffffffffffUL, 1UL), 0xffffffffffffffffUL)
  assert_eq(@bridges.restore64(1UL, 0xffffffffffffffffUL), 1UL)
}

///|
test "fill contract composes with a safe read" {
  let xs : FixedArray[Int] = [0, 1, 2, 3]
  assert_eq(@bridges.fill_and_read(xs, 1, 2, 7), Some(7))
  assert_eq(xs, [0, 7, 7, 3])
  assert_eq(@bridges.fill_and_read(xs, 4, 0, 9), None)
  assert_eq(@bridges.fill_and_read(xs, 3, 2, 9), None)
  assert_eq(xs, [0, 7, 7, 3])
}
