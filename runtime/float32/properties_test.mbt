// Generate integer encodings: the built-in Arbitrary for Float only samples
// [0, 1), which misses exceptional values and most exponents. NaN payloads are
// deliberately not compared; every other value is checked bit for bit.

///|
fn expected(bits : UInt) -> @float32.Expected {
  if (bits & 0x7fffffffU) > 0x7f800000U {
    AnyNaN
  } else {
    Bits(bits)
  }
}

///|
test "quickcheck: binary32 classification and bit roundtrip" {
  @quickcheck.check(
    (bits : UInt) => {
      let value = @float32.from_bits(bits)
      let magnitude = bits & 0x7fffffffU
      @float32.is_nan(value) == (magnitude > 0x7f800000U) &&
      @float32.is_infinite(value) == (magnitude == 0x7f800000U) &&
      @float32.eq(value, value) == (magnitude <= 0x7f800000U) &&
      !@float32.less(value, value) &&
      @float32.matches(value, expected(bits))
    },
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: binary32 sign operations match the encoding" {
  @quickcheck.check(
    (bits : UInt) => {
      let value = @float32.from_bits(bits)
      @float32.matches(@float32.neg(value), expected(bits ^ 0x80000000U)) &&
      @float32.matches(@float32.abs(value), expected(bits & 0x7fffffffU))
    },
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: finite binary32 self subtraction gives positive zero" {
  @quickcheck.check(
    (bits : UInt) => {
      let value = @float32.from_bits(bits)
      @float32.matches(@float32.sub(value, value), Bits(0U))
    },
    filter=bits => (bits & 0x7fffffffU) < 0x7f800000U,
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: binary32 multiplication and division by one preserve values" {
  @quickcheck.check(
    (bits : UInt) => {
      let value = @float32.from_bits(bits)
      let one = @float32.from_bits(0x3f800000U)
      @float32.matches(@float32.mul(value, one), expected(bits)) &&
      @float32.matches(@float32.div(value, one), expected(bits))
    },
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: binary32 addition and multiplication commute" {
  @quickcheck.check(
    (input : (UInt, UInt)) => {
      let x = @float32.from_bits(input.0)
      let y = @float32.from_bits(input.1)
      let sum = @float32.add(x, y)
      let product = @float32.mul(x, y)
      @float32.matches(@float32.add(y, x), expected(@float32.to_bits(sum))) &&
      @float32.matches(@float32.mul(y, x), expected(@float32.to_bits(product)))
    },
    count=1000,
    seed=20260914,
  )
}
