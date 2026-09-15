///|
/// Return the exact Int result, or None precisely when it is unrepresentable.
pub fn checked_add(
  x : Int,
  y : Int,
) -> Int? where {
  proof_require: -2147483648 <= x && x <= 2147483647,
  proof_require: -2147483648 <= y && y <= 2147483647,
  proof_ensure: result => {
    match result {
      None =>
        !in_range(@integer.add(@integer.from_int(x), @integer.from_int(y)))
      Some(value) =>
        in_range(@integer.add(@integer.from_int(x), @integer.from_int(y))) &&
        @integer.eq(
          @integer.from_int(value),
          @integer.add(@integer.from_int(x), @integer.from_int(y)),
        )
    }
  },
} {
  let overflow = (y > 0 && x > 2147483647 - y) || (y < 0 && x < -2147483648 - y)
  if overflow {
    None
  } else {
    Some(x + y)
  }
}

///|
/// Return the exact Int result, or None precisely when it is unrepresentable.
pub fn checked_sub(
  x : Int,
  y : Int,
) -> Int? where {
  proof_require: -2147483648 <= x && x <= 2147483647,
  proof_require: -2147483648 <= y && y <= 2147483647,
  proof_ensure: result => {
    match result {
      None =>
        !in_range(@integer.sub(@integer.from_int(x), @integer.from_int(y)))
      Some(value) =>
        in_range(@integer.sub(@integer.from_int(x), @integer.from_int(y))) &&
        @integer.eq(
          @integer.from_int(value),
          @integer.sub(@integer.from_int(x), @integer.from_int(y)),
        )
    }
  },
} {
  let overflow = (y > 0 && x < -2147483648 + y) || (y < 0 && x > 2147483647 + y)
  if overflow {
    None
  } else {
    Some(x - y)
  }
}

///|
/// Return the exact Int result, or None precisely when it is unrepresentable.
pub fn checked_mul(
  x : Int,
  y : Int,
) -> Int? where {
  proof_require: -2147483648 <= x && x <= 2147483647,
  proof_require: -2147483648 <= y && y <= 2147483647,
  proof_ensure: result => {
    match result {
      None =>
        !in_range(@integer.mul(@integer.from_int(x), @integer.from_int(y)))
      Some(value) =>
        in_range(@integer.mul(@integer.from_int(x), @integer.from_int(y))) &&
        @integer.eq(
          @integer.from_int(value),
          @integer.mul(@integer.from_int(x), @integer.from_int(y)),
        )
    }
  },
} {
  let overflow = if x > 0 {
    if y > 0 {
      x > 2147483647 / y
    } else if y < 0 {
      y < -2147483648 / x
    } else {
      false
    }
  } else if x < 0 {
    if y > 0 {
      x < -2147483648 / y
    } else if y < 0 {
      x < 2147483647 / y
    } else {
      false
    }
  } else {
    false
  }
  if overflow {
    None
  } else {
    Some(x * y)
  }
}
