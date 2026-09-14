///|
/// Independent invariant checker: equal black height and no red-red edge.
/// Returns (black height, total height), rejecting every invalid subtree.
fn inspect_balance(node : Node) -> (Int, Int)? {
  match node {
    Empty => Some((0, 0))
    Branch(color, left, _, right) => {
      if color is Red &&
        (left is Branch(Red, _, _, _) || right is Branch(Red, _, _, _)) {
        return None
      }
      match (inspect_balance(left), inspect_balance(right)) {
        (Some((lb, lh)), Some((rb, rh))) if lb == rb =>
          Some(
            (
              lb + (if color is Black { 1 } else { 0 }),
              1 + (if lh > rh { lh } else { rh }),
            ),
          )
        _ => None
      }
    }
  }
}

///|
fn balanced(tree : SearchTree) -> Bool {
  if tree.root is Branch(Red, _, _, _) {
    return false
  }
  match inspect_balance(tree.root) {
    Some((black_height, height)) => height <= 2 * black_height
    None => false
  }
}

///|
test "quickcheck: insertion preserves red-black balance at every prefix" {
  @quickcheck.check(
    (values : Array[Int]) => {
      let mut tree = empty()
      for value in values {
        tree = insert(tree, value)
        if !balanced(tree) {
          return false
        }
      }
      true
    },
    count=1000,
    max_size=128,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "red-black invariants hold for long ordered and duplicate inputs" {
  for descending in [false, true] {
    let mut tree = empty()
    for index in 0..<12000 {
      tree = insert(tree, if descending { 12000 - index } else { index })
      if index % 256 == 0 {
        assert_true(balanced(tree))
      }
    }
    assert_true(balanced(tree))
    let before = to_array(tree)
    for value in before {
      tree = insert(tree, value)
    }
    assert_true(balanced(tree))
    assert_eq(to_array(tree), before)
  }
}

///|
test "balance checker rejects red-red edges and unequal black height" {
  assert_false(
    balanced({
      root: Branch(
        Black,
        Branch(Red, Branch(Red, Empty, 1, Empty), 2, Empty),
        3,
        Empty,
      ),
    }),
  )
  assert_false(
    balanced({ root: Branch(Black, Branch(Black, Empty, 1, Empty), 2, Empty), }),
  )
}
