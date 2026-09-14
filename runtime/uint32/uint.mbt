///|
/// Wrapping addition with a proof over unbounded integers. Branches avoid
/// intermediate overflow even with Why3's checked machine-integer prelude.
pub fn add(
  x : UInt,
  y : UInt,
) -> UInt where {
  proof_require: 0U <= x && x <= 0xffffffffU,
  proof_require: 0U <= y && y <= 0xffffffffU,
  proof_ensure: result => Bv32::eq(model(result), Bv32::add(model(x), model(y))),
  proof_ensure: result => 0U <= result && result <= 0xffffffffU,
  proof_ensure: result => {
    @integer.eq(
      @integer.from_uint(result),
      @integer.modulo(
        @integer.add(@integer.from_uint(x), @integer.from_uint(y)),
        @integer.add(@integer.from_uint(0xffffffffU), @integer.from_uint(1U)),
      ),
    )
  },
} {
  let room = 0xffffffffU - x
  if y > room {
    y - room - 1U
  } else {
    x + y
  }
}

///|
/// Wrapping subtraction, with no underflow in intermediate operations.
pub fn sub(
  x : UInt,
  y : UInt,
) -> UInt where {
  proof_require: 0U <= x && x <= 0xffffffffU,
  proof_require: 0U <= y && y <= 0xffffffffU,
  proof_ensure: result => Bv32::eq(model(result), Bv32::sub(model(x), model(y))),
  proof_ensure: result => 0U <= result && result <= 0xffffffffU,
  proof_ensure: result => {
    @integer.eq(
      @integer.from_uint(result),
      @integer.modulo(
        @integer.sub(@integer.from_uint(x), @integer.from_uint(y)),
        @integer.add(@integer.from_uint(0xffffffffU), @integer.from_uint(1U)),
      ),
    )
  },
} {
  if x >= y {
    x - y
  } else {
    0xffffffffU - (y - x - 1U)
  }
}

///|
/// Unsigned comparison, proved equivalent to bitvector unsigned order.
pub fn less(
  x : UInt,
  y : UInt,
) -> Bool where {
  proof_require: 0U <= x && x <= 0xffffffffU,
  proof_require: 0U <= y && y <= 0xffffffffU,
  proof_ensure: result => result == Bv32::ult(model(x), model(y)),
} {
  x < y
}
