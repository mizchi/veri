///|
test "checked arithmetic includes exact endpoints and rejects overflow" {
  assert_eq(@int64.checked_add(9223372036854775807L, 1L), None)
  assert_eq(@int64.checked_add(-9223372036854775808L, -1L), None)
  assert_eq(@int64.checked_sub(-9223372036854775808L, 1L), None)
  assert_eq(@int64.checked_sub(9223372036854775807L, -1L), None)
  assert_eq(@int64.checked_mul(-9223372036854775808L, -1L), None)
  assert_eq(@int64.checked_mul(-1L, -9223372036854775808L), None)
  assert_eq(
    @int64.checked_mul(-9223372036854775808L, 1L),
    Some(-9223372036854775808L),
  )
  assert_eq(@int64.checked_mul(-9223372036854775808L, 0L), Some(0L))
  assert_eq(
    @int64.checked_add(9223372036854775807L, 0L),
    Some(9223372036854775807L),
  )
  assert_eq(
    @int64.checked_sub(-1L, -9223372036854775808L),
    Some(9223372036854775807L),
  )
}
