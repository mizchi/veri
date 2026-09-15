///|
test "peek handles a deferred front without consuming the queue" {
  let queue : Queue[Int] = {
    front: @linked.empty(),
    back: @linked.from_array([3, 2, 1]),
  }
  assert_eq(queue.peek(), Some(1))
  assert_eq(queue.peek(), Some(1))
  assert_eq(queue.to_array(), [1, 2, 3])
  let (value, rest) = queue.pop().unwrap()
  assert_eq(value, 1)
  assert_eq(rest.to_array(), [2, 3])
  assert_eq(queue.to_array(), [1, 2, 3])
}
