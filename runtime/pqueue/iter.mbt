///|
/// Traverse in ascending order, keeping duplicates. Runtime-tested.
/// Extraction is lazy and leaves the original queue unchanged.
pub fn IntMinQueue::iter(self : IntMinQueue) -> Iter[Int] {
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
