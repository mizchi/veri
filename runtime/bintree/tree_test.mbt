///|
priv struct GeneratedTree(@bintree.Tree[Int]) derive(Debug)

///|
impl @quickcheck.Arbitrary for GeneratedTree with fn arbitrary(size, state) {
  if size <= 0 || state.next_uint(limit=4U) == 0U {
    GeneratedTree(@bintree.Empty)
  } else {
    let left : GeneratedTree = @quickcheck.Arbitrary::arbitrary(
      size / 2,
      state.split(),
    )
    let right : GeneratedTree = @quickcheck.Arbitrary::arbitrary(
      size / 2,
      state.split(),
    )
    let value = @quickcheck.Arbitrary::arbitrary(size, state)
    GeneratedTree(@bintree.Node(left.0, value, right.0))
  }
}

///|
impl @shrink.Shrink for GeneratedTree with fn shrink(self) {
  match self.0 {
    Empty => [||]
    Node(left, value, right) => {
      let subtrees = [
        GeneratedTree(@bintree.Empty),
        GeneratedTree(left),
        GeneratedTree(right),
      ]
      subtrees
      .iter()
      .concat(
        @shrink.Shrink::shrink(value).map(smaller => {
          GeneratedTree(@bintree.Node(left, smaller, right))
        }),
      )
      .concat(
        @shrink.Shrink::shrink(GeneratedTree(left)).map(smaller => {
          GeneratedTree(@bintree.Node(smaller.0, value, right))
        }),
      )
      .concat(
        @shrink.Shrink::shrink(GeneratedTree(right)).map(smaller => {
          GeneratedTree(@bintree.Node(left, value, smaller.0))
        }),
      )
    }
  }
}

///|
fn reference(tree : @bintree.Tree[Int]) -> Array[Int] {
  match tree {
    Empty => []
    Node(left, value, right) => reference(left) + [value] + reference(right)
  }
}

///|
test "tree shrinking reduces nested values without discarding their parents" {
  let leaf = @bintree.Node(@bintree.Empty, 100, @bintree.Empty)
  let tree = GeneratedTree(@bintree.Node(leaf, 0, leaf))
  let candidates = @shrink.Shrink::shrink(tree).to_array()
  assert_true(
    candidates.any(candidate => {
      candidate.0 is Node(Node(Empty, 0, Empty), 0, Node(Empty, 100, Empty))
    }),
  )
  assert_true(
    candidates.any(candidate => {
      candidate.0 is Node(Node(Empty, 100, Empty), 0, Node(Empty, 0, Empty))
    }),
  )
}

///|
test "quickcheck: binary tree traversal matches the recursive array model" {
  @quickcheck.check(
    (tree : GeneratedTree) => {
      @linked.to_array(@bintree.inorder(tree.0)) == reference(tree.0)
    },
    count=1000,
    max_size=64,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "inorder handles a deep left spine without repeated concatenation" {
  let mut tree : @bintree.Tree[Int] = @bintree.Empty
  for value in 0..<20000 {
    tree = @bintree.Node(tree, value, @bintree.Empty)
  }
  assert_eq(
    @linked.to_array(@bintree.inorder(tree)),
    Array::makei(20000, i => i),
  )
}
