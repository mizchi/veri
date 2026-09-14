///|
test "wrapping addition at both ends" {
  assert_eq(@uint32.add(0xffffffffU, 1U), 0U)
  assert_eq(@uint32.add(0xffffffffU, 0xffffffffU), 0xffffffffU - 1U)
  assert_eq(@uint32.add(12U, 30U), 42U)
}

///|
test "wrapping subtraction at both ends" {
  assert_eq(@uint32.sub(0U, 1U), 0xffffffffU)
  assert_eq(@uint32.sub(0U, 0xffffffffU), 1U)
  assert_eq(@uint32.sub(42U, 12U), 30U)
}

///|
test "unsigned comparison keeps the high bit positive" {
  assert_true(@uint32.less(0U, 0xffffffffU))
  assert_false(@uint32.less(0xffffffffU, 0U))
  assert_false(@uint32.less(42U, 42U))
}
