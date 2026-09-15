///|
test "checked conversions use native types and preserve numeric values" {
  assert_eq(@conversion.checked_int_to_uint(-1), None)
  assert_eq(@conversion.int_to_int64(-1), -1L)
  assert_eq(@conversion.checked_int_to_uint64(-1), None)
  assert_eq(@conversion.checked_uint_to_int(2147483648U), None)
  assert_eq(@conversion.uint_to_int64(4294967295U), 4294967295L)
  assert_eq(@conversion.uint_to_uint64(4294967295U), 4294967295UL)
  assert_eq(@conversion.checked_int64_to_int(2147483648L), None)
  assert_eq(@conversion.checked_int64_to_uint(4294967295L), Some(4294967295U))
  assert_eq(@conversion.checked_int64_to_uint64(-1L), None)
  assert_eq(@conversion.checked_uint64_to_int(2147483648UL), None)
  assert_eq(@conversion.checked_uint64_to_uint(4294967296UL), None)
  assert_eq(@conversion.checked_uint64_to_int64(9223372036854775808UL), None)
  assert_false(@conversion.can_int_to_uint(-1))
  assert_true(@conversion.can_uint_to_int64(4294967295U))
}
