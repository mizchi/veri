///|
/// Greatest common divisor of unsigned 32-bit values; gcd(0, 0) = 0.
pub fn gcd(
  x : UInt,
  y : UInt,
) -> UInt where {
  proof_require: 0U <= x && x <= 0xffffffffU,
  proof_require: 0U <= y && y <= 0xffffffffU,
  proof_ensure: result => {
    @integer.eq(
      @integer.from_uint(result),
      @logic_number.gcd(@integer.from_uint(x), @integer.from_uint(y)),
    )
  },
  proof_ensure: result => 0U <= result && result <= 0xffffffffU,
  proof_decrease: y,
} {
  if y == 0U {
    x
  } else {
    gcd(y, x % y)
  }
}

///|
/// Signed division rounded toward zero. None denotes division by zero or
/// the sole unrepresentable Int quotient, Int::min_value / -1.
pub fn div_rem(
  x : Int,
  y : Int,
) -> (Int, Int)? where {
  proof_require: -2147483648 <= x && x <= 2147483647,
  proof_require: -2147483648 <= y && y <= 2147483647,
  proof_ensure: result => {
    match result {
      None => y == 0 || (x == -2147483648 && y == -1)
      Some((q, r)) =>
        y != 0 &&
        !(x == -2147483648 && y == -1) &&
        @integer.eq(
          @integer.from_int(q),
          @integer.trunc_div(@integer.from_int(x), @integer.from_int(y)),
        ) &&
        @integer.eq(
          @integer.from_int(r),
          @integer.trunc_mod(@integer.from_int(x), @integer.from_int(y)),
        )
    }
  },
} {
  if y == 0 || (x == -2147483648 && y == -1) {
    None
  } else {
    Some((x / y, x % y))
  }
}

///|
/// Nonnegative remainder for a positive modulus; None for a nonpositive modulus.
pub fn euclidean_mod(
  x : Int,
  modulus : Int,
) -> Int? where {
  proof_require: -2147483648 <= x && x <= 2147483647,
  proof_require: -2147483648 <= modulus && modulus <= 2147483647,
  proof_ensure: result => {
    match result {
      None => modulus <= 0
      Some(r) =>
        modulus > 0 &&
        0 <= r &&
        r < modulus &&
        @integer.eq(
          @integer.from_int(r),
          @integer.modulo(@integer.from_int(x), @integer.from_int(modulus)),
        )
    }
  },
} {
  if modulus <= 0 {
    None
  } else {
    let r = x % modulus
    proof_assert @integer.eq(
      @integer.from_int(r),
      @integer.trunc_mod(@integer.from_int(x), @integer.from_int(modulus)),
    )
    proof_assert @integer.eq(
      @integer.modulo(@integer.from_int(x), @integer.from_int(modulus)),
      @integer_laws.normalized_mod(
        @integer.from_int(x),
        @integer.from_int(modulus),
      ),
    )
    if r < 0 {
      proof_assert @integer.eq(
        @integer.modulo(@integer.from_int(x), @integer.from_int(modulus)),
        @integer.add(@integer.from_int(r), @integer.from_int(modulus)),
      )
      Some(r + modulus)
    } else {
      proof_assert @integer.eq(
        @integer.modulo(@integer.from_int(x), @integer.from_int(modulus)),
        @integer.from_int(r),
      )
      Some(r)
    }
  }
}
