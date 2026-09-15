///|
test "checked conversions reject sign loss and narrowing loss" {
  assert_eq(@conversion.checked_int_to_uint(-1), None)
  assert_eq(@conversion.checked_uint_to_int(0x80000000U), None)
  assert_eq(@conversion.checked_int64_to_int(2147483648L), None)
  assert_eq(@conversion.checked_uint64_to_uint(4294967296UL), None)
  assert_eq(@conversion.checked_uint64_to_int64(0x8000000000000000UL), None)
  assert_eq(@conversion.checked_int64_to_uint64(-1L), None)
  assert_eq(@conversion.int_to_int64(-2147483648), -2147483648L)
  assert_eq(@conversion.uint_to_uint64(0xffffffffU), 4294967295UL)
}
