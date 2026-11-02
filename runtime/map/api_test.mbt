///|
test "core type identity and independent copies" {
  let value : @map.Map[Int32, Int32] = Map([])
  value.set(1, 2)
  let copy : @map.Map[Int32, Int32] = value.copy()
  copy.set(1, 3)
  assert_eq(value.get(1), Some(2))
  assert_true(@map.matches_entries(value, [(1, 2)]))
  assert_false(@map.matches_entries(value, [(1, 2), (1, 2)]))
  assert_false(@map.matches_entries(value, [(1, 3)]))
  assert_false(@map.matches_entries(value, []))
}
