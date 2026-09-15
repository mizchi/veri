///|
/// Prepend a value, leaving this list unchanged.
pub fn[T] List::prepend(
  self : List[T],
  value : T,
) -> List[T] where {
  proof_ensure: result => {
    @logic_list.eq(model(result), @logic_list.cons(value, model(self)))
  },
} {
  cons(value, self)
}

///|
/// Consume an iterator in order, as in core/list. Runtime-tested.
pub fn[T] List::from_iter(iter : Iter[T]) -> List[T] {
  let mut reversed : List[T] = Nil
  for value in iter {
    reversed = Cons(value, reversed)
  }
  reversed.rev()
}

///|
/// Traverse in list order without allocating an intermediate array.
/// Each call creates an independent, consuming iterator. Runtime-tested.
pub fn[T] List::iter(self : List[T]) -> Iter[T] {
  let mut rest = self
  Iter::new(fn() {
    match rest {
      Nil => None
      Cons(value, tail) => {
        rest = tail
        Some(value)
      }
    }
  })
}
