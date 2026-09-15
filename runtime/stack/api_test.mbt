///|
test "stack methods and iteration use LIFO order" {
  let empty : @stack.Stack[Int] = @stack.Stack::new()
  let xs = empty.push(1).push(2)
  assert_true(empty.is_empty())
  assert_eq(xs.peek(), Some(2))
  assert_eq(xs.iter().to_array(), [2, 1])
  assert_eq(xs.iter().to_array(), xs.to_array())
  assert_eq(empty.iter().to_array(), [])
  guard xs.pop() is Some((head, tail)) else { fail("missing head") }
  assert_eq(head, 2)
  assert_eq(tail.to_array(), [1])
}
