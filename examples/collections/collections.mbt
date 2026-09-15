///|
pub fn stack_last(
  first : Int,
  last : Int,
) -> Int? where {
  proof_ensure: result => {
    match result {
      Some(value) => value == last
      None => false
    }
  },
} {
  @stack.Stack::new().push(first).push(last).peek()
}

///|
pub fn queue_first(
  first : Int,
  last : Int,
) -> Int? where {
  proof_ensure: result => {
    match result {
      Some(value) => value == first
      None => false
    }
  },
} {
  @queue.Queue::new().push(first).push(last).peek()
}

///|
pub fn minimum_of_two(
  first : Int,
  last : Int,
) -> Int? where {
  proof_ensure: result => {
    match result {
      Some(value) =>
        value <= first && value <= last && (value == first || value == last)
      None => false
    }
  },
} {
  @pqueue.IntMinQueue::new().push(first).push(last).peek()
}

///|
pub fn inserted_is_found(
  value : Int,
) -> Bool where {
  proof_ensure: result => result,
} {
  @search.IntSet::new().insert(value).contains(value)
}

///|
pub fn empty_search_misses(
  value : Int,
) -> Bool where {
  proof_ensure: result => result == false,
} {
  @search.IntSet::new().contains(value)
}
