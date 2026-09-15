///|
/// Inorder values in a fresh array, without constructing a linked output list.
/// Uses an explicit stack and handles deep trees in either direction. Runtime-tested.
pub fn[T] Tree::to_array(self : Tree[T]) -> Array[T] {
  let result = []
  let pending : Array[Tree[T]] = []
  let mut current = self
  while true {
    match current {
      Empty => {
        guard pending.pop() is Some(Node(_, value, right)) else { break }
        result.push(value)
        current = right
      }
      Node(Empty, value, right) => {
        result.push(value)
        current = right
      }
      Node(left, _, _) => {
        pending.push(current)
        current = left
      }
    }
  }
  result
}

///|
/// Inorder traversal with O(height) auxiliary storage and no output array.
/// Each call creates independent traversal state. Runtime-tested.
pub fn[T] Tree::iter(self : Tree[T]) -> Iter[T] {
  let pending : Array[Tree[T]] = []
  let mut current = self
  Iter::new(fn() {
    while current is Node(left, _, _) {
      pending.push(current)
      current = left
    }
    guard pending.pop() is Some(Node(_, value, right)) else { return None }
    current = right
    Some(value)
  })
}
