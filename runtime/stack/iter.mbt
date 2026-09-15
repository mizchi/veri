///|
/// Traverse from the top without changing the stack. Runtime-tested.
pub fn[T] Stack::iter(self : Stack[T]) -> Iter[T] {
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
