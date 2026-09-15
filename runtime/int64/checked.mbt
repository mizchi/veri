///|
/// Return the exact Int64 result, or None precisely when it is unrepresentable.
pub fn checked_add(
  x : Int64,
  y : Int64,
) -> Int64? where {
  proof_require: -9223372036854775808L <= x && x <= 9223372036854775807L,
  proof_require: -9223372036854775808L <= y && y <= 9223372036854775807L,
  proof_ensure: result => {
    match result {
      None =>
        !in_range(@integer.add(@integer.from_int64(x), @integer.from_int64(y)))
      Some(value) =>
        in_range(@integer.add(@integer.from_int64(x), @integer.from_int64(y))) &&
        @integer.eq(
          @integer.from_int64(value),
          @integer.add(@integer.from_int64(x), @integer.from_int64(y)),
        )
    }
  },
} {
  let overflow = (y > 0L && x > 9223372036854775807L - y) ||
    (y < 0L && x < -9223372036854775808L - y)
  if overflow {
    None
  } else {
    Some(x + y)
  }
}

///|
/// Return the exact Int64 result, or None precisely when it is unrepresentable.
pub fn checked_sub(
  x : Int64,
  y : Int64,
) -> Int64? where {
  proof_require: -9223372036854775808L <= x && x <= 9223372036854775807L,
  proof_require: -9223372036854775808L <= y && y <= 9223372036854775807L,
  proof_ensure: result => {
    match result {
      None =>
        !in_range(@integer.sub(@integer.from_int64(x), @integer.from_int64(y)))
      Some(value) =>
        in_range(@integer.sub(@integer.from_int64(x), @integer.from_int64(y))) &&
        @integer.eq(
          @integer.from_int64(value),
          @integer.sub(@integer.from_int64(x), @integer.from_int64(y)),
        )
    }
  },
} {
  let overflow = (y > 0L && x < -9223372036854775808L + y) ||
    (y < 0L && x > 9223372036854775807L + y)
  if overflow {
    None
  } else {
    Some(x - y)
  }
}

///|
/// Return the exact Int64 result, or None precisely when it is unrepresentable.
pub fn checked_mul(
  x : Int64,
  y : Int64,
) -> Int64? where {
  proof_require: -9223372036854775808L <= x && x <= 9223372036854775807L,
  proof_require: -9223372036854775808L <= y && y <= 9223372036854775807L,
  proof_ensure: result => {
    match result {
      None =>
        !in_range(@integer.mul(@integer.from_int64(x), @integer.from_int64(y)))
      Some(value) =>
        in_range(@integer.mul(@integer.from_int64(x), @integer.from_int64(y))) &&
        @integer.eq(
          @integer.from_int64(value),
          @integer.mul(@integer.from_int64(x), @integer.from_int64(y)),
        )
    }
  },
} {
  let overflow = if x > 0L {
    if y > 0L {
      x > 9223372036854775807L / y
    } else if y < 0L {
      y < -9223372036854775808L / x
    } else {
      false
    }
  } else if x < 0L {
    if y > 0L {
      x < -9223372036854775808L / y
    } else if y < 0L {
      x < 9223372036854775807L / y
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
