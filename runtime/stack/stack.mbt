///|
#valtype
pub struct Stack[T] {
  priv contents : @linked.List[T]
}

///|
#inline
pub fn[T] empty() -> Stack[T] where {
  proof_ensure: result => @logic_list.is_empty(model(result)),
} {
  { contents: @linked.empty(), }
}

///|
#owned(stack, value)
#inline
pub fn[T] push(
  stack : Stack[T],
  value : T,
) -> Stack[T] where {
  proof_ensure: result => {
    @logic_list.eq(model(result), @logic_list.cons(value, model(stack)))
  },
} {
  { contents: @linked.cons(value, stack.contents), }
}

///|
#owned(stack)
#inline
pub fn[T] pop(
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
  match stack.contents {
    Nil => None
    Cons(value, rest) => Some((value, { contents: rest, }))
  }
}

///|
#inline
pub fn[T] peek(
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
  match stack.contents {
    Nil => None
    Cons(value, _) => Some(value)
  }
}

///|
#inline
pub fn[T] is_empty(
  stack : Stack[T],
) -> Bool where {
  proof_ensure: result => result == @logic_list.is_empty(model(stack)),
} {
  @linked.is_empty(stack.contents)
}

///|
/// Top first, in a fresh array. Conversion is runtime-tested.
pub fn[T] to_array(stack : Stack[T]) -> Array[T] {
  @linked.to_array(stack.contents)
}
