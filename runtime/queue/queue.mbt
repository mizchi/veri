///|
/// Persistent two-list FIFO. Back is stored in reverse insertion order.
#valtype
pub struct Queue[T] {
  priv front : @linked.List[T]
  priv back : @linked.List[T]
}

///|
#inline
#as_free_fn(empty)
pub fn[T] Queue::new() -> Queue[T] where {
  proof_ensure: result => @logic_list.is_empty(model(result)),
} {
  { front: @linked.empty(), back: @linked.empty(), }
}

///|
#owned(queue, value)
#inline
#as_free_fn(push)
pub fn[T] Queue::push(
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
  let ready = normalize(queue)
  match ready.front {
    Nil => {
      proof_assert @logic_list.is_empty(model(queue))
      { front: @linked.cons(value, @linked.empty()), back: @linked.empty(), }
    }
    Cons(_, _) => { front: ready.front, back: @linked.cons(value, ready.back), }
  }
}

///|
#owned(queue)
#inline
fn[T] normalize(
  queue : Queue[T],
) -> Queue[T] where {
  proof_ensure: result => @logic_list.eq(model(result), model(queue)),
  proof_ensure: result => normalized(result),
} {
  match queue.front {
    Nil => {
      let result = {
        front: @linked.reverse(queue.back),
        back: @linked.empty(),
      }
      proof_assert @logic_list.eq(model(result), @linked.model(result.front))
      result
    }
    Cons(_, _) => queue
  }
}

///|
#owned(queue)
#inline
#as_free_fn(pop)
pub fn[T] Queue::pop(
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
      let result = normalize({ front: rest, back: ready.back, })
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
#inline
#as_free_fn(peek)
pub fn[T] Queue::peek(
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
  match queue.front {
    Nil => last(queue.back)
    Cons(value, rest) => {
      proof_assert @logic_list.eq(
        @linked.model(queue.front),
        @logic_list.cons(value, @linked.model(rest)),
      )
      proof_assert @logic_list.eq(
        model(queue),
        @logic_list.cons(
          value,
          @logic_list.append(
            @linked.model(rest),
            @logic_list.reverse(@linked.model(queue.back)),
          ),
        ),
      )
      Some(value)
    }
  }
}

///|
#as_free_fn(is_empty)
pub fn[T] Queue::is_empty(
  queue : Queue[T],
) -> Bool where {
  proof_ensure: result => result == @logic_list.is_empty(model(queue)),
} {
  @linked.is_empty(queue.front) && @linked.is_empty(queue.back)
}

///|
/// FIFO order, in a fresh array. Conversion is runtime-tested.
#as_free_fn(to_array)
pub fn[T] Queue::to_array(queue : Queue[T]) -> Array[T] {
  let result = @linked.to_array(queue.front)
  result.append(@linked.to_array(@linked.reverse(queue.back)))
  result
}

///|
/// Inspect the oldest deferred element without constructing a reversed list.
fn[T] last(
  xs : @linked.List[T],
) -> T? where {
  proof_decrease: xs,
  proof_ensure: result => {
    match result {
      None => @logic_list.is_empty(@linked.model(xs))
      Some(value) =>
        !@logic_list.is_empty(@linked.model(xs)) &&
        same(value, @logic_list.head(@logic_list.reverse(@linked.model(xs))))
    }
  },
} {
  match xs {
    Nil => None
    Cons(value, Nil) => Some(value)
    Cons(_, rest) => last(rest)
  }
}
