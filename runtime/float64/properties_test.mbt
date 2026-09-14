// Generate integer encodings: the built-in Arbitrary for Double only samples
// [0, 1), which misses exceptional values and most exponents. NaN payloads are
// deliberately not compared; every other value is checked bit for bit.

///|
fn expected(bits : UInt64) -> @float64.Expected {
  if (bits & 0x7fffffffffffffffUL) > 0x7ff0000000000000UL {
    AnyNaN
  } else {
    Bits(bits)
  }
}

///|
test "quickcheck: binary64 classification and bit roundtrip" {
  @quickcheck.check(
    (bits : UInt64) => {
      let value = @float64.from_bits(bits)
      let magnitude = bits & 0x7fffffffffffffffUL
      @float64.is_nan(value) == (magnitude > 0x7ff0000000000000UL) &&
      @float64.is_infinite(value) == (magnitude == 0x7ff0000000000000UL) &&
      @float64.eq(value, value) == (magnitude <= 0x7ff0000000000000UL) &&
      !@float64.less(value, value) &&
      @float64.matches(value, expected(bits))
    },
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: binary64 sign operations match the encoding" {
  @quickcheck.check(
    (bits : UInt64) => {
      let value = @float64.from_bits(bits)
      @float64.matches(
        @float64.neg(value),
        expected(bits ^ 0x8000000000000000UL),
      ) &&
      @float64.matches(
        @float64.abs(value),
        expected(bits & 0x7fffffffffffffffUL),
      )
    },
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: finite binary64 self subtraction gives positive zero" {
  @quickcheck.check(
    (bits : UInt64) => {
      let value = @float64.from_bits(bits)
      @float64.matches(@float64.sub(value, value), Bits(0UL))
    },
    filter=bits => (bits & 0x7fffffffffffffffUL) < 0x7ff0000000000000UL,
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: binary64 multiplication and division by one preserve values" {
  @quickcheck.check(
    (bits : UInt64) => {
      let value = @float64.from_bits(bits)
      let one = @float64.from_bits(0x3ff0000000000000UL)
      @float64.matches(@float64.mul(value, one), expected(bits)) &&
      @float64.matches(@float64.div(value, one), expected(bits))
    },
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: binary64 addition and multiplication commute" {
  @quickcheck.check(
    (input : (UInt64, UInt64)) => {
      let x = @float64.from_bits(input.0)
      let y = @float64.from_bits(input.1)
      let sum = @float64.add(x, y)
      let product = @float64.mul(x, y)
      @float64.matches(@float64.add(y, x), expected(@float64.to_bits(sum))) &&
      @float64.matches(@float64.mul(y, x), expected(@float64.to_bits(product)))
    },
    count=1000,
    seed=20260914,
  )
}
