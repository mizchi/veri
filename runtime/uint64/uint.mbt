///|
/// Wrapping addition with a proof over unbounded integers. Branches avoid
/// intermediate overflow even with Why3's checked machine-integer prelude.
pub fn add(
  x : UInt64,
  y : UInt64,
) -> UInt64 where {
  proof_require: 0UL <= x && x <= 0xffffffffffffffffUL,
  proof_require: 0UL <= y && y <= 0xffffffffffffffffUL,
  proof_ensure: result => @bv64.eq(model(result), @bv64.add(model(x), model(y))),
  proof_ensure: result => 0UL <= result && result <= 0xffffffffffffffffUL,
  proof_ensure: result => {
    @integer.eq(
      @integer.from_uint64(result),
      @integer.modulo(
        @integer.add(@integer.from_uint64(x), @integer.from_uint64(y)),
        @integer.add(
          @integer.from_uint64(0xffffffffffffffffUL),
          @integer.from_uint64(1UL),
        ),
      ),
    )
  },
} {
  let room = 0xffffffffffffffffUL - x
  if y > room {
    y - room - 1UL
  } else {
    x + y
  }
}

///|
/// Wrapping subtraction, with no underflow in intermediate operations.
pub fn sub(
  x : UInt64,
  y : UInt64,
) -> UInt64 where {
  proof_require: 0UL <= x && x <= 0xffffffffffffffffUL,
  proof_require: 0UL <= y && y <= 0xffffffffffffffffUL,
  proof_ensure: result => @bv64.eq(model(result), @bv64.sub(model(x), model(y))),
  proof_ensure: result => 0UL <= result && result <= 0xffffffffffffffffUL,
  proof_ensure: result => {
    @integer.eq(
      @integer.from_uint64(result),
      @integer.modulo(
        @integer.sub(@integer.from_uint64(x), @integer.from_uint64(y)),
        @integer.add(
          @integer.from_uint64(0xffffffffffffffffUL),
          @integer.from_uint64(1UL),
        ),
      ),
    )
  },
} {
  if x >= y {
    x - y
  } else {
    0xffffffffffffffffUL - (y - x - 1UL)
  }
}

///|
/// Unsigned comparison, proved equivalent to bitvector unsigned order.
pub fn less(
  x : UInt64,
  y : UInt64,
) -> Bool where {
  proof_require: 0UL <= x && x <= 0xffffffffffffffffUL,
  proof_require: 0UL <= y && y <= 0xffffffffffffffffUL,
  proof_ensure: result => result == @bv64.ult(model(x), model(y)),
} {
  x < y
}
