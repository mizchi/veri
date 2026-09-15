///|
test "checked arithmetic includes exact endpoints and rejects overflow" {
  assert_eq(@int32.checked_add(2147483647, 1), None)
  assert_eq(@int32.checked_add(-2147483648, -1), None)
  assert_eq(@int32.checked_sub(-2147483648, 1), None)
  assert_eq(@int32.checked_sub(2147483647, -1), None)
  assert_eq(@int32.checked_mul(-2147483648, -1), None)
  assert_eq(@int32.checked_mul(-1, -2147483648), None)
  assert_eq(@int32.checked_mul(-2147483648, 1), Some(-2147483648))
  assert_eq(@int32.checked_mul(-2147483648, 0), Some(0))
  assert_eq(@int32.checked_add(2147483647, 0), Some(2147483647))
  assert_eq(@int32.checked_sub(-1, -2147483648), Some(2147483647))
}
