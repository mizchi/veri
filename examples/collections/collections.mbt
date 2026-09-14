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
  @stack.peek(@stack.push(@stack.push(@stack.empty(), first), last))
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
  @queue.peek(@queue.push(@queue.push(@queue.empty(), first), last))
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
  @pqueue.peek(@pqueue.push(@pqueue.push(@pqueue.empty(), first), last))
}

///|
pub fn inserted_is_found(
  value : Int,
) -> Bool where {
  proof_ensure: result => result,
} {
  @search.contains(@search.insert(@search.empty(), value), value)
}

///|
pub fn empty_search_misses(
  value : Int,
) -> Bool where {
  proof_ensure: result => result == false,
} {
  @search.contains(@search.empty(), value)
}
