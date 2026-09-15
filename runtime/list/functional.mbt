///|
/// Apply f exactly once per element, from left to right. Runtime-tested;
/// algebra.map describes the corresponding pure operation in specifications.
pub fn[A, B] List::map(self : List[A], f : (A) -> B raise?) -> List[B] raise? {
  let mut reversed : List[B] = Nil
  let mut rest = self
  while rest is Cons(x, tail) {
    reversed = Cons(f(x), reversed)
    rest = tail
  }
  reversed.rev()
}

///|
/// Ordered left fold. Runtime callbacks may have effects; algebraic laws apply
/// only to pure operations satisfying the explicit predicates in algebra.
pub fn[A, B] List::fold(
  self : List[A],
  init~ : B,
  f : (B, A) -> B raise?,
) -> B raise? {
  let mut acc = init
  let mut rest = self
  while rest is Cons(x, tail) {
    acc = f(acc, x)
    rest = tail
  }
  acc
}
