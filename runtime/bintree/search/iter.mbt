///|
/// Traverse unique keys in ascending order with O(height) auxiliary storage.
/// Each call creates independent traversal state. Runtime-tested.
pub fn IntSet::iter(self : IntSet) -> Iter[Int] {
  let pending : Array[Node] = []
  let mut current = self.root
  Iter::new(fn() {
    while current is Branch(_, left, _, _) {
      pending.push(current)
      current = left
    }
    guard pending.pop() is Some(Branch(_, _, value, right)) else { return None }
    current = right
    Some(value)
  })
}
