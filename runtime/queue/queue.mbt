///|
/// Persistent two-list FIFO. Back is stored in reverse insertion order.
pub struct Queue[T] {
  priv front : @linked.List[T]
  priv back : @linked.List[T]
}

///|
pub fn[T] empty() -> Queue[T] where {
  proof_ensure: result => @logic_list.is_empty(model(result)),
} {
  { front: @linked.empty(), back: @linked.empty(), }
}

///|
pub fn[T] push(
  queue : Queue[T],
  value : T,
) -> Queue[T] where {
  proof_ensure: result => {
    @logic_list.eq(
      model(result),
      @logic_list.append(
        model(queue),
        @logic_list.cons(value, @logic_list.empty()),
      ),
    )
  },
} {
  { front: queue.front, back: @linked.cons(value, queue.back), }
}

///|
fn[T] normalize(
  queue : Queue[T],
) -> Queue[T] where {
  proof_ensure: result => @logic_list.eq(model(result), model(queue)),
  proof_ensure: result => normalized(result),
} {
  if @linked.is_empty(queue.front) {
    let result = { front: @linked.reverse(queue.back), back: @linked.empty(), }
    proof_assert @logic_list.eq(model(result), @linked.model(result.front))
    result
  } else {
    queue
  }
}

///|
pub fn[T] pop(
  queue : Queue[T],
) -> (T, Queue[T])? where {
  proof_ensure: result => {
    match result {
      None => @logic_list.is_empty(model(queue))
      Some((value, rest)) =>
        @logic_list.eq(model(queue), @logic_list.cons(value, model(rest)))
    }
  },
} {
  let ready = normalize(queue)
  match ready.front {
    Nil => None
    Cons(value, rest) => {
      proof_assert @logic_list.eq(
        @linked.model(ready.front),
        @logic_list.cons(value, @linked.model(rest)),
      )
      let result = { front: rest, back: ready.back, }
      proof_assert @logic_list.eq(
        model(result),
        @logic_list.append(
          @linked.model(rest),
          @logic_list.reverse(@linked.model(ready.back)),
        ),
      )
      proof_assert @logic_list.eq(
        model(ready),
        @logic_list.append(
          @logic_list.cons(value, @linked.model(rest)),
          @logic_list.reverse(@linked.model(ready.back)),
        ),
      )
      proof_assert @logic_list.eq(
        model(ready),
        @logic_list.cons(value, model(result)),
      )
      Some((value, result))
    }
  }
}

///|
pub fn[T] peek(
  queue : Queue[T],
) -> T? where {
  proof_ensure: result => {
    match result {
      None => @logic_list.is_empty(model(queue))
      Some(value) =>
        @logic_list.is_empty(model(queue)) == false &&
        same(value, @logic_list.head(model(queue)))
    }
  },
} {
  match pop(queue) {
    None => None
    Some((value, _)) => Some(value)
  }
}

///|
pub fn[T] is_empty(
  queue : Queue[T],
) -> Bool where {
  proof_ensure: result => result == @logic_list.is_empty(model(queue)),
} {
  @linked.is_empty(queue.front) && @linked.is_empty(queue.back)
}

///|
/// FIFO order, in a fresh array. Conversion is runtime-tested.
pub fn[T] to_array(queue : Queue[T]) -> Array[T] {
  let result = @linked.to_array(queue.front)
  result.append(@linked.to_array(@linked.reverse(queue.back)))
  result
}
