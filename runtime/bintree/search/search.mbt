///|
pub fn empty() -> @tree.Tree[Int] where {
  proof_ensure: result => valid(result),
  proof_ensure: result => @logic_tree.is_empty(@tree.model(result)),
} {
  @tree.Empty
}

///|
/// Persistent insertion; equal keys are kept only once. O(height).
pub fn insert(
  tree : @tree.Tree[Int],
  value : Int,
) -> @tree.Tree[Int] where {
  proof_decrease: tree,
  proof_require: valid(tree),
  proof_ensure: result => valid(result),
  proof_ensure: result => inserted(tree, value, result),
} {
  match tree {
    Empty => @tree.Node(@tree.Empty, value, @tree.Empty)
    Node(left, key, right) =>
      if value < key {
        @tree.Node(insert(left, value), key, right)
      } else if key < value {
        @tree.Node(left, key, insert(right, value))
      } else {
        tree
      }
  }
}

///|
pub fn contains(
  tree : @tree.Tree[Int],
  value : Int,
) -> Bool where {
  proof_decrease: tree,
  proof_require: valid(tree),
  proof_ensure: result => result == @logic_tree.mem(value, @tree.model(tree)),
} {
  match tree {
    Empty => false
    Node(left, key, right) =>
      if value < key {
        contains(left, value)
      } else if key < value {
        contains(right, value)
      } else {
        true
      }
  }
}
