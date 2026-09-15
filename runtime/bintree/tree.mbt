///|
/// Immutable binary-tree shape; stored values may themselves be mutable.
pub(all) enum Tree[T] {
  Empty
  Node(Tree[T], T, Tree[T])
} derive(Debug)

///|
#as_free_fn(empty)
pub fn[T] Tree::new() -> Tree[T] where {
  proof_ensure: result => @logic_tree.is_empty(model(result)),
} {
  Empty
}

///|
#as_free_fn(node)
pub fn[T] Tree::node(
  left : Tree[T],
  value : T,
  right : Tree[T],
) -> Tree[T] where {
  proof_ensure: result => {
    @logic_tree.eq(
      model(result),
      @logic_tree.node(model(left), value, model(right)),
    )
  },
} {
  Node(left, value, right)
}

///|
#as_free_fn(inorder)
pub fn[T] Tree::inorder(
  tree : Tree[T],
) -> @linked.List[T] where {
  proof_ensure: result => {
    @logic_list.eq(@linked.model(result), @logic_tree.inorder(model(tree)))
  },
} {
  inorder_into(tree, @linked.empty())
}

///|
/// Prepend the traversal to its continuation, allocating each output cell once.
fn[T] inorder_into(
  tree : Tree[T],
  acc : @linked.List[T],
) -> @linked.List[T] where {
  proof_decrease: tree,
  proof_ensure: result => {
    @logic_list.eq(
      @linked.model(result),
      @logic_list.append(@logic_tree.inorder(model(tree)), @linked.model(acc)),
    )
  },
} {
  match tree {
    Empty => acc
    Node(left, value, right) =>
      inorder_into(left, @linked.cons(value, inorder_into(right, acc)))
  }
}
