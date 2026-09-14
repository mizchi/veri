///|
test "collection clients compose the public APIs" {
  assert_eq(@collections.stack_last(10, 20), Some(20))
  assert_eq(@collections.queue_first(10, 20), Some(10))
  assert_eq(@collections.minimum_of_two(10, -20), Some(-20))
  assert_true(@collections.inserted_is_found(42))
}
