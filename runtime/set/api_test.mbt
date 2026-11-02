///|
test "core type identity and independent copies" {
  let value : @set.Set[Int32] = Set([])
  value.add(1)
  let copy : @set.Set[Int32] = value.copy()
  copy.add(2)
  assert_false(value.contains(2))
  assert_true(@set.matches_elements(value, [1]))
  assert_false(@set.matches_elements(value, [1, 1]))
  assert_false(@set.matches_elements(value, [2]))
  assert_false(@set.matches_elements(value, []))
}
