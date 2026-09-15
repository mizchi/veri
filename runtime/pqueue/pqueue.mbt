///|
/// Persistent min-priority queue of Int values, retaining duplicates.
/// Pairing heap: O(1) push/peek; pop uses two passes over the root children.
/// Node fields represent first child, value and next sibling.
priv enum Heap {
  Empty
  Node(Heap, Int, Heap)
}

///|
#valtype
pub struct IntMinQueue {
  priv values : Heap
}

///|
#inline
#as_free_fn(empty)
pub fn IntMinQueue::new() -> IntMinQueue where {
  proof_ensure: result => valid(result),
  proof_ensure: result => @bag.eq(model(result), @bag.empty()),
} {
  { values: Empty, }
}

///|
/// Link an implicit root (children, value) with an existing heap. Avoid allocating
/// a temporary root just to discard it during the link.
#owned(children, heap)
fn link(
  children : Heap,
  value : Int,
  heap : Heap,
) -> Heap where {
  proof_require: ordered(children) && all_ge(value, children),
  proof_require: ordered(heap) && root(heap),
  proof_ensure: result => ordered(result) && root(result),
  proof_ensure: result => {
    @bag.eq(
      contents(result),
      @bag.union(@bag.add(value, contents(children)), contents(heap)),
    )
  },
} {
  match heap {
    Empty => Node(children, value, Empty)
    Node(other, head, _) =>
      if value <= head {
        match children {
          Empty => Node(heap, value, Empty)
          Node(_, _, _) => Node(Node(other, head, children), value, Empty)
        }
      } else {
        Node(Node(children, value, other), head, Empty)
      }
  }
}

///|
/// Pair siblings from left to right, storing merged roots in reverse order.
#owned(forest, acc)
fn pair_roots(
  forest : Heap,
  acc : Heap,
) -> Heap where {
  proof_decrease: heap_size(forest),
  proof_require: ordered(forest) && ordered(acc),
  proof_ensure: result => ordered(result),
  proof_ensure: result => {
    @bag.eq(contents(result), @bag.union(contents(forest), contents(acc)))
  },
} {
  match forest {
    Empty => acc
    Node(a, x, Empty) => Node(a, x, acc)
    Node(a, x, Node(b, y, rest)) =>
      if x <= y {
        pair_roots(rest, Node(Node(b, y, a), x, acc))
      } else {
        pair_roots(rest, Node(Node(a, x, b), y, acc))
      }
  }
}

///|
/// Merge paired roots from right to left. Both passes are tail recursive.
#owned(forest, acc)
fn merge_roots(
  forest : Heap,
  acc : Heap,
) -> Heap where {
  proof_decrease: forest,
  proof_require: ordered(forest) && ordered(acc) && root(acc),
  proof_ensure: result => ordered(result) && root(result),
  proof_ensure: result => {
    @bag.eq(contents(result), @bag.union(contents(forest), contents(acc)))
  },
} {
  match forest {
    Empty => acc
    Node(children, value, rest) => merge_roots(rest, link(children, value, acc))
  }
}

///|
#owned(queue)
#as_free_fn(push)
pub fn IntMinQueue::push(
  queue : IntMinQueue,
  value : Int,
) -> IntMinQueue where {
  proof_require: valid(queue),
  proof_ensure: result => valid(result),
  proof_ensure: result => @bag.eq(model(result), @bag.add(value, model(queue))),
} {
  { values: link(Empty, value, queue.values), }
}

///|
#owned(queue)
#inline
#as_free_fn(pop)
pub fn IntMinQueue::pop(
  queue : IntMinQueue,
) -> (Int, IntMinQueue)? where {
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
    Node(children, value, _) =>
      Some(
        (value, { values: merge_roots(pair_roots(children, Empty), Empty), }),
      )
  }
}

///|
#inline
#as_free_fn(peek)
pub fn IntMinQueue::peek(
  queue : IntMinQueue,
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
#as_free_fn(is_empty)
pub fn IntMinQueue::is_empty(
  queue : IntMinQueue,
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
#as_free_fn(to_array)
pub fn IntMinQueue::to_array(queue : IntMinQueue) -> Array[Int] {
  let result = []
  let mut rest = queue
  while pop(rest) is Some((value, tail)) {
    result.push(value)
    rest = tail
  }
  result
}
