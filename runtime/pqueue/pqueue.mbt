///|
/// Persistent min-priority queue of Int values, retaining duplicates.
/// Uses an ordered list: push O(n), peek/pop O(1).
pub struct PriorityQueue {
  priv values : @linked.List[Int]
}

///|
pub fn empty() -> PriorityQueue where {
  proof_ensure: result => valid(result),
  proof_ensure: result => @bag.eq(model(result), @bag.empty()),
} {
  { values: @linked.Nil, }
}

///|
fn insert(
  xs : @linked.List[Int],
  value : Int,
) -> @linked.List[Int] where {
  proof_decrease: xs,
  proof_require: sorted(xs),
  proof_ensure: result => sorted(result),
  proof_ensure: result => {
    @bag.eq(contents(result), @bag.add(value, contents(xs)))
  },
} {
  match xs {
    Nil => @linked.Cons(value, @linked.Nil)
    Cons(head, rest) =>
      if value <= head {
        @linked.Cons(value, xs)
      } else {
        @linked.Cons(head, insert(rest, value))
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
  { values: insert(queue.values, value), }
}

///|
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
    Nil => None
    Cons(value, rest) => Some((value, { values: rest, }))
  }
}

///|
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
    Nil => None
    Cons(value, _) => Some(value)
  }
}

///|
pub fn is_empty(
  queue : PriorityQueue,
) -> Bool where {
  proof_ensure: result => result == @bag.eq(model(queue), @bag.empty()),
} {
  match queue.values {
    Nil => true
    Cons(_, _) => false
  }
}

///|
/// Ascending order; fresh array, checked by runtime tests.
pub fn to_array(queue : PriorityQueue) -> Array[Int] {
  @linked.to_array(queue.values)
}
