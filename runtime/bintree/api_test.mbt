///|
test "tree methods and lazy iteration follow inorder on an arbitrary shape" {
  let empty : @bintree.Tree[Int] = @bintree.Tree::new()
  let left = @bintree.Tree::node(empty, 3, empty)
  let right = @bintree.Tree::node(empty, 1, empty)
  let tree = @bintree.Tree::node(left, 2, right)
  assert_eq(tree.iter().take(2).to_array(), [3, 2])
  assert_eq(tree.iter().to_array(), [3, 2, 1])
  assert_eq(tree.inorder().to_array(), [3, 2, 1])
  assert_eq(tree.to_array(), [3, 2, 1])
  tree.to_array().clear()
  assert_eq(tree.to_array(), [3, 2, 1])
  assert_eq(empty.to_array(), [])
  assert_eq(empty.iter().to_array(), [])
}

///|
test "direct array traversal handles deep trees in both directions" {
  let mut left : @bintree.Tree[Int] = @bintree.Empty
  let mut right : @bintree.Tree[Int] = @bintree.Empty
  for value in 0..<20000 {
    left = @bintree.Node(left, value, @bintree.Empty)
    right = @bintree.Node(@bintree.Empty, 19999 - value, right)
  }
  let expected = Array::makei(20000, i => i)
  assert_eq(left.to_array(), expected)
  assert_eq(right.to_array(), expected)
}
