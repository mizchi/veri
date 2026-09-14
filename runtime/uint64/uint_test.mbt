///|
test "wrapping addition at both ends" {
  assert_eq(@uint64.add(0xffffffffffffffffUL, 1UL), 0UL)
  assert_eq(
    @uint64.add(0xffffffffffffffffUL, 0xffffffffffffffffUL),
    0xffffffffffffffffUL - 1UL,
  )
  assert_eq(@uint64.add(12UL, 30UL), 42UL)
}

///|
test "wrapping subtraction at both ends" {
  assert_eq(@uint64.sub(0UL, 1UL), 0xffffffffffffffffUL)
  assert_eq(@uint64.sub(0UL, 0xffffffffffffffffUL), 1UL)
  assert_eq(@uint64.sub(42UL, 12UL), 30UL)
}

///|
test "unsigned comparison keeps the high bit positive" {
  assert_true(@uint64.less(0UL, 0xffffffffffffffffUL))
  assert_false(@uint64.less(0xffffffffffffffffUL, 0UL))
  assert_false(@uint64.less(42UL, 42UL))
}
