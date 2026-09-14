///|
pub struct Stack[T] {
  priv contents : @linked.List[T]
}

///|
pub fn[T] empty() -> Stack[T] where {
  proof_ensure: result => @logic_list.is_empty(model(result)),
} {
  { contents: @linked.empty(), }
}

///|
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
  match @linked.uncons(stack.contents) {
    None => None
    Some((value, rest)) => Some((value, { contents: rest, }))
  }
}

///|
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
  match @linked.uncons(stack.contents) {
    None => None
    Some((value, _)) => Some(value)
  }
}

///|
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
