///|
/// Immutable spine. Values stored in the list may themselves be mutable.
pub(all) enum List[T] {
  Nil
  Cons(T, List[T])
}

///|
#as_free_fn(empty)
pub fn[T] List::new() -> List[T] where {
  proof_ensure: result => @logic_list.eq(model(result), @logic_list.empty()),
} {
  let result : List[T] = Nil
  proof_assert @logic_list.is_empty(model(result))
  result
}

///|
#owned(value, xs)
#inline
pub fn[T] cons(
  value : T,
  xs : List[T],
) -> List[T] where {
  proof_ensure: result => {
    @logic_list.eq(model(result), @logic_list.cons(value, model(xs)))
  },
} {
  Cons(value, xs)
}

///|
#inline
#as_free_fn(is_empty)
pub fn[T] List::is_empty(
  xs : List[T],
) -> Bool where {
  proof_ensure: result => result == @logic_list.is_empty(model(xs)),
} {
  match xs {
    Nil => true
    Cons(_, _) => false
  }
}

///|
#inline
#as_free_fn(uncons)
pub fn[T] List::uncons(
  xs : List[T],
) -> (T, List[T])? where {
  proof_ensure: result => {
    match result {
      None => @logic_list.is_empty(model(xs))
      Some((value, rest)) =>
        @logic_list.eq(model(xs), @logic_list.cons(value, model(rest)))
    }
  },
} {
  match xs {
    Nil => None
    Cons(value, rest) => Some((value, rest))
  }
}

///|
#owned(xs, ys)
#as_free_fn(append)
pub fn[T] List::concat(
  xs : List[T],
  ys : List[T],
) -> List[T] where {
  proof_decrease: xs,
  proof_ensure: result => {
    @logic_list.eq(model(result), @logic_list.append(model(xs), model(ys)))
  },
} {
  match xs {
    Nil => {
      proof_assert @logic_list.is_empty(model(xs))
      ys
    }
    Cons(value, rest) => Cons(value, append(rest, ys))
  }
}

///|
#owned(xs, acc)
fn[T] reverse_into(
  xs : List[T],
  acc : List[T],
) -> List[T] where {
  proof_decrease: xs,
  proof_ensure: result => {
    @logic_list.eq(
      model(result),
      @logic_list.append(@logic_list.reverse(model(xs)), model(acc)),
    )
  },
} {
  match xs {
    Nil => {
      proof_assert @logic_list.is_empty(model(xs))
      acc
    }
    Cons(value, rest) => reverse_into(rest, Cons(value, acc))
  }
}

///|
#owned(xs)
#as_free_fn(reverse)
pub fn[T] List::rev(
  xs : List[T],
) -> List[T] where {
  proof_ensure: result => {
    @logic_list.eq(model(result), @logic_list.reverse(model(xs)))
  },
} {
  reverse_into(xs, empty())
}

///|
/// The mathematical length must fit in a runtime Int.
#as_free_fn(length)
pub fn[T] List::length(
  xs : List[T],
) -> Int where {
  proof_require: @integer.le(
    @logic_list.length(model(xs)),
    @integer.from_int(2147483647),
  ),
  proof_ensure: result => {
    @integer.eq(@integer.from_int(result), @logic_list.length(model(xs)))
  },
} {
  length_from(xs, 0)
}

///|
fn[T] length_from(
  xs : List[T],
  count : Int,
) -> Int where {
  proof_decrease: xs,
  proof_require: 0 <= count,
  proof_require: @integer.le(
    @integer.add(@integer.from_int(count), @logic_list.length(model(xs))),
    @integer.from_int(2147483647),
  ),
  proof_ensure: result => {
    @integer.eq(
      @integer.from_int(result),
      @integer.add(@integer.from_int(count), @logic_list.length(model(xs))),
    )
  },
} {
  match xs {
    Nil => count
    Cons(_, rest) => length_from(rest, count + 1)
  }
}

///|
/// Convenience conversion, covered by runtime property tests.
#as_free_fn(from_array)
pub fn[T] List::from_array(values : ArrayView[T]) -> List[T] {
  let mut result = Nil
  for index = values.length() - 1; index >= 0; index = index - 1 {
    result = Cons(values[index], result)
  }
  result
}

///|
/// A fresh array in list order; does not mutate the input spine.
#owned(xs)
#as_free_fn(to_array)
pub fn[T] List::to_array(xs : List[T]) -> Array[T] {
  let result = []
  let mut rest = xs
  while rest is Cons(value, tail) {
    result.push(value)
    rest = tail
  }
  result
}
