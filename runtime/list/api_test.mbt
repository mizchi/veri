///|
test "list methods preserve order and compose with Iter" {
  let empty : @list.List[Int] = @list.List::new()
  let xs = empty.prepend(2).prepend(1)
  let ys = @list.List::from_array([3, 4])
  assert_true(empty.is_empty())
  assert_eq(xs.length(), 2)
  assert_eq(xs.concat(ys).iter().to_array(), [1, 2, 3, 4])
  assert_eq(xs.rev().iter().to_array(), [2, 1])
  assert_eq(xs.iter().to_array(), [1, 2])
  assert_eq(empty.iter().to_array(), [])
  guard xs.uncons() is Some((head, tail)) else { fail("missing head") }
  assert_eq(head, 1)
  assert_eq(tail.to_array(), [2])
}
