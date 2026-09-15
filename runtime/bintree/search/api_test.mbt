///|
test "IntSet methods and iteration preserve sorted unique keys" {
  let empty = @search.IntSet::new()
  let xs = empty.insert(3).insert(-1).insert(3).insert(2)
  assert_eq(xs.iter().take(2).to_array(), [-1, 2])
  assert_eq(xs.iter().to_array(), [-1, 2, 3])
  assert_eq(xs.to_array(), [-1, 2, 3])
  assert_eq(empty.iter().to_array(), [])
  assert_true(xs.contains(2))
  assert_false(empty.contains(2))
}
