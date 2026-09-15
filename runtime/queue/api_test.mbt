///|
test "queue methods preserve old versions and iterate in FIFO order" {
  let empty : @queue.Queue[Int] = @queue.Queue::new()
  let queue = empty.push(1).push(2).push(3)
  assert_true(empty.is_empty())
  assert_eq(queue.peek(), Some(1))
  assert_eq(queue.iter().map(x => x * 2).to_array(), [2, 4, 6])
  assert_eq(queue.iter().to_array(), [1, 2, 3])
  assert_eq(empty.iter().to_array(), [])
  guard queue.pop() is Some((first, rest)) else { fail("missing head") }
  assert_eq(first, 1)
  assert_eq(rest.to_array(), [2, 3])
  assert_eq(queue.to_array(), @queue.to_array(queue))
}
