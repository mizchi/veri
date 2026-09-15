///|
test "IntMinQueue methods and lazy iteration retain sorted duplicates" {
  let empty = @pqueue.IntMinQueue::new()
  let xs = empty.push(3).push(-1).push(3).push(2)
  assert_true(empty.is_empty())
  assert_eq(xs.peek(), Some(-1))
  assert_eq(xs.iter().take(2).to_array(), [-1, 2])
  assert_eq(xs.iter().to_array(), [-1, 2, 3, 3])
  assert_eq(xs.to_array(), [-1, 2, 3, 3])
  assert_eq(empty.iter().to_array(), [])
  guard xs.pop() is Some((head, tail)) else { fail("missing minimum") }
  assert_eq(head, -1)
  assert_eq(tail.to_array(), [2, 3, 3])
}
