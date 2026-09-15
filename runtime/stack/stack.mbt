///|
/// The stored spine is also the pop result, avoiding a second tuple allocation.
#valtype
pub enum Stack[T] {
  Stack((T, Stack[T])?)
}

///|
#inline
#as_free_fn(empty)
pub fn[T] Stack::new() -> Stack[T] where {
  proof_ensure: result => @logic_list.is_empty(model(result)),
} {
  Stack(None)
}

///|
#owned(stack, value)
#inline
#as_free_fn(push)
pub fn[T] Stack::push(
  stack : Stack[T],
  value : T,
) -> Stack[T] where {
  proof_ensure: result => {
    @logic_list.eq(model(result), @logic_list.cons(value, model(stack)))
  },
} {
  Stack(Some((value, stack)))
}

///|
#owned(stack)
#inline
#as_free_fn(pop)
pub fn[T] Stack::pop(
  stack : Stack[T],
) -> (T, Stack[T])? where {
  proof_ensure: result => {
    match result {
      None => @logic_list.is_empty(model(stack))
      Some((value, rest)) =>
        @logic_list.eq(model(stack), @logic_list.cons(value, model(rest)))
    }
  },
} {
  match stack {
    Stack(contents) => contents
  }
}

///|
#inline
#as_free_fn(peek)
pub fn[T] Stack::peek(
  stack : Stack[T],
) -> T? where {
  proof_ensure: result => {
    match result {
      None => @logic_list.is_empty(model(stack))
      Some(value) =>
        @logic_list.is_empty(model(stack)) == false &&
        same(value, @logic_list.head(model(stack)))
    }
  },
} {
  match stack {
    Stack(None) => None
    Stack(Some((value, _))) => Some(value)
  }
}

///|
#inline
#as_free_fn(is_empty)
pub fn[T] Stack::is_empty(
  stack : Stack[T],
) -> Bool where {
  proof_ensure: result => result == @logic_list.is_empty(model(stack)),
} {
  match stack {
    Stack(None) => true
    Stack(Some(_)) => false
  }
}

///|
/// Top first, in a fresh array. Conversion is runtime-tested.
#owned(stack)
#as_free_fn(to_array)
pub fn[T] Stack::to_array(stack : Stack[T]) -> Array[T] {
  let result = []
  let mut rest = stack
  while rest.pop() is Some((value, tail)) {
    result.push(value)
    rest = tail
  }
  result
}
