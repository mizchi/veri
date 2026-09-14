///|
priv enum Color {
  Red
  Black
}

///|
priv enum Node {
  Empty
  Branch(Color, Node, Int, Node)
}

///|
/// Persistent red-black search tree of unique Int keys.
#valtype
pub struct SearchTree {
  priv root : Node
}

///|
pub fn empty() -> SearchTree where {
  proof_ensure: result => valid(result),
  proof_ensure: result => @logic_tree.is_empty(model(result)),
} {
  { root: Empty, }
}

///|
/// Restore red-red violations on the insertion path (Okasaki, 1999).
fn balance_left(
  color : Color,
  left : Node,
  key : Int,
  right : Node,
) -> Node where {
  proof_require: ordered(Branch(color, left, key, right)),
  proof_ensure: result => ordered(result),
  proof_ensure: result => same_members(Branch(color, left, key, right), result),
} {
  match (color, left) {
    (Black, Branch(Red, ll, lk, lr)) =>
      match (ll, lr) {
        (Branch(Red, a, x, b), c) =>
          Branch(Red, Branch(Black, a, x, b), lk, Branch(Black, c, key, right))
        (a, Branch(Red, b, y, c)) =>
          Branch(Red, Branch(Black, a, lk, b), y, Branch(Black, c, key, right))
        _ => Branch(color, left, key, right)
      }
    _ => Branch(color, left, key, right)
  }
}

///|
/// Restore red-red violations on the insertion path (Okasaki, 1999).
fn balance_right(
  color : Color,
  left : Node,
  key : Int,
  right : Node,
) -> Node where {
  proof_require: ordered(Branch(color, left, key, right)),
  proof_ensure: result => ordered(result),
  proof_ensure: result => same_members(Branch(color, left, key, right), result),
} {
  match (color, right) {
    (Black, Branch(Red, rl, rk, rr)) =>
      match (rl, rr) {
        (Branch(Red, b, y, c), d) =>
          Branch(Red, Branch(Black, left, key, b), y, Branch(Black, c, rk, d))
        (b, Branch(Red, c, z, d)) =>
          Branch(Red, Branch(Black, left, key, b), rk, Branch(Black, c, z, d))
        _ => Branch(color, left, key, right)
      }
    _ => Branch(color, left, key, right)
  }
}

///|
fn insert_node(
  tree : Node,
  value : Int,
) -> Node where {
  proof_decrease: tree,
  proof_require: ordered(tree),
  proof_ensure: result => ordered(result),
  proof_ensure: result => inserted_node(tree, value, result),
} {
  match tree {
    Empty => Branch(Red, Empty, value, Empty)
    Branch(color, left, key, right) =>
      if value < key {
        balance_left(color, insert_node(left, value), key, right)
      } else if key < value {
        balance_right(color, left, key, insert_node(right, value))
      } else {
        tree
      }
  }
}

///|
/// Persistent insertion with rebalancing; equal keys are kept only once.
pub fn insert(
  tree : SearchTree,
  value : Int,
) -> SearchTree where {
  proof_require: valid(tree),
  proof_ensure: result => valid(result),
  proof_ensure: result => inserted(tree, value, result),
} {
  let root = match insert_node(tree.root, value) {
    Empty => Empty
    Branch(_, left, key, right) => Branch(Black, left, key, right)
  }
  { root, }
}

///|
fn contains_node(
  tree : Node,
  value : Int,
) -> Bool where {
  proof_decrease: tree,
  proof_require: ordered(tree),
  proof_ensure: result => result == @logic_tree.mem(value, node_model(tree)),
} {
  match tree {
    Empty => false
    Branch(_, left, key, right) =>
      if value < key {
        contains_node(left, value)
      } else if key < value {
        contains_node(right, value)
      } else {
        true
      }
  }
}

///|
pub fn contains(
  tree : SearchTree,
  value : Int,
) -> Bool where {
  proof_require: valid(tree),
  proof_ensure: result => result == @logic_tree.mem(value, model(tree)),
} {
  contains_node(tree.root, value)
}

///|
/// Sorted unique contents in a fresh array. Conversion is runtime-tested.
pub fn to_array(tree : SearchTree) -> Array[Int] {
  fn visit(node : Node, output : Array[Int]) -> Unit {
    match node {
      Empty => ()
      Branch(_, left, key, right) => {
        visit(left, output)
        output.push(key)
        visit(right, output)
      }
    }
  }
  let output = []
  visit(tree.root, output)
  output
}
