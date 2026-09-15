///|
/// Traverse in FIFO order without an intermediate array. Runtime-tested.
/// Each iterator owns its traversal state; the queue remains unchanged.
pub fn[T] Queue::iter(self : Queue[T]) -> Iter[T] {
  let mut rest = self
  Iter::new(fn() {
    match rest.pop() {
      None => None
      Some((value, tail)) => {
        rest = tail
        Some(value)
      }
    }
  })
}
