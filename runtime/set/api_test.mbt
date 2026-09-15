///|
test "core type identity and independent copies" {
  let value : @set.Set[Int] = Set([])
  value.add(1)
  let copy : Set[Int] = value.copy()
  copy.add(2)
  assert_false(value.contains(2))
  assert_true(@set.matches_elements(value, [1]))
  assert_false(@set.matches_elements(value, [1, 1]))
  assert_false(@set.matches_elements(value, [2]))
  assert_false(@set.matches_elements(value, []))
}
