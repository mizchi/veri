///|
/// Immutable spine. Values stored in the list may themselves be mutable.
pub(all) enum List[T] {
  Nil
  Cons(T, List[T])
}

///|
pub fn[T] empty() -> List[T] where {
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
pub fn[T] is_empty(
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
pub fn[T] uncons(
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
pub fn[T] append(
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
pub fn[T] reverse(
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
pub fn[T] length(
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
pub fn[T] from_array(values : ArrayView[T]) -> List[T] {
  let mut result = Nil
  for index = values.length() - 1; index >= 0; index = index - 1 {
    result = Cons(values[index], result)
  }
  result
}

///|
/// A fresh array in list order; does not mutate the input spine.
pub fn[T] to_array(xs : List[T]) -> Array[T] {
  let result = []
  let mut rest = xs
  while rest is Cons(value, tail) {
    result.push(value)
    rest = tail
  }
  result
}
