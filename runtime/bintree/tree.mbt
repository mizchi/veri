///|
/// Immutable binary-tree shape; stored values may themselves be mutable.
pub(all) enum Tree[T] {
  Empty
  Node(Tree[T], T, Tree[T])
} derive(Debug)

///|
pub fn[T] empty() -> Tree[T] where {
  proof_ensure: result => @logic_tree.is_empty(model(result)),
} {
  Empty
}

///|
pub fn[T] node(
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
pub fn[T] inorder(
  tree : Tree[T],
) -> @linked.List[T] where {
  proof_decrease: tree,
  proof_ensure: result => {
    @logic_list.eq(@linked.model(result), @logic_tree.inorder(model(tree)))
  },
} {
  match tree {
    Empty => @linked.empty()
    Node(left, value, right) =>
      @linked.append(inorder(left), @linked.cons(value, inorder(right)))
  }
}
