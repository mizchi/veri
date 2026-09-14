///|
test "clamp preserves values and handles both bounds" {
  assert_eq(@bounds.clamp(-1, 0, 10), 0)
  assert_eq(@bounds.clamp(10, 0, 10), 9)
  assert_eq(@bounds.clamp(4, 0, 10), 4)
}

///|
test "clamp handles machine integer endpoints without overflow" {
  assert_eq(@bounds.clamp(-2147483648, 0, 2147483647), 0)
  assert_eq(@bounds.clamp(2147483647, -2147483648, -2147483647), -2147483648)
}
