///|
/// Persistent min-priority queue of Int values, retaining duplicates.
/// Skew heap: amortized O(log n) push/pop along a linear update history, O(1) peek.
priv enum Heap {
  Empty
  Node(Heap, Int, Heap)
}

///|
#valtype
pub struct PriorityQueue {
  priv values : Heap
}

///|
#inline
pub fn empty() -> PriorityQueue where {
  proof_ensure: result => valid(result),
  proof_ensure: result => @bag.eq(model(result), @bag.empty()),
} {
  { values: Empty, }
}

///|
/// Skew-heap meld: exchange children on every step.
fn merge(
  left : Heap,
  right : Heap,
) -> Heap where {
  proof_decrease: total_size(left, right),
  proof_require: ordered(left) && ordered(right),
  proof_ensure: result => ordered(result),
  proof_ensure: result => {
    @bag.eq(contents(result), @bag.union(contents(left), contents(right)))
  },
} {
  match (left, right) {
    (Empty, _) => right
    (_, Empty) => left
    (Node(a, x, b), Node(c, y, d)) =>
      if x <= y {
        Node(merge(b, right), x, a)
      } else {
        Node(merge(left, d), y, c)
      }
  }
}

///|
pub fn push(
  queue : PriorityQueue,
  value : Int,
) -> PriorityQueue where {
  proof_require: valid(queue),
  proof_ensure: result => valid(result),
  proof_ensure: result => @bag.eq(model(result), @bag.add(value, model(queue))),
} {
  let singleton = Node(Empty, value, Empty)
  proof_assert @bag.eq(contents(singleton), @bag.singleton(value))
  { values: merge(singleton, queue.values), }
}

///|
#inline
pub fn pop(
  queue : PriorityQueue,
) -> (Int, PriorityQueue)? where {
  proof_require: valid(queue),
  proof_ensure: result => {
    match result {
      None => @bag.eq(model(queue), @bag.empty())
      Some((value, rest)) =>
        valid(rest) &&
        minimum(value, queue) &&
        @bag.eq(model(queue), @bag.add(value, model(rest)))
    }
  },
} {
  match queue.values {
    Empty => None
    Node(left, value, right) => Some((value, { values: merge(left, right), }))
  }
}

///|
#inline
pub fn peek(
  queue : PriorityQueue,
) -> Int? where {
  proof_require: valid(queue),
  proof_ensure: result => {
    match result {
      None => @bag.eq(model(queue), @bag.empty())
      Some(value) => minimum(value, queue)
    }
  },
} {
  match queue.values {
    Empty => None
    Node(_, value, _) => Some(value)
  }
}

///|
pub fn is_empty(
  queue : PriorityQueue,
) -> Bool where {
  proof_ensure: result => result == @bag.eq(model(queue), @bag.empty()),
} {
  match queue.values {
    Empty => true
    Node(_, _, _) => false
  }
}

///|
/// Ascending order; fresh array, checked by runtime tests.
pub fn to_array(queue : PriorityQueue) -> Array[Int] {
  let result = []
  let mut rest = queue
  while pop(rest) is Some((value, tail)) {
    result.push(value)
    rest = tail
  }
  result
}
