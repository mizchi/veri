///|
test "matches compares encodings including the sign of zero" {
  assert_true(@float64.matches(0.0, Bits(0UL)))
  assert_true(@float64.matches(-0.0, Bits(0x8000000000000000UL)))
  assert_false(@float64.matches(-0.0, Bits(0UL)))
  assert_false(@float64.matches(0.0, Bits(0x8000000000000000UL)))
  assert_false(@float64.matches(1.0, Bits(0x3ff0000000000001UL)))
}

///|
test "matches accepts NaN payload variation but rejects finite values and infinity" {
  assert_true(
    @float64.matches(0x7ff8000000000001UL.reinterpret_as_double(), AnyNaN),
  )
  assert_true(
    @float64.matches(0xfff8000000001234UL.reinterpret_as_double(), AnyNaN),
  )
  assert_false(@float64.matches(1.0, AnyNaN))
  assert_false(
    @float64.matches(0x7ff0000000000000UL.reinterpret_as_double(), AnyNaN),
  )
}

///|
test "binary64 addition is not associative" {
  let a = 9007199254740992.0
  let b = -9007199254740992.0
  let c = 0.5
  assert_eq(a + b + c, 0.5)
  assert_eq(a + (b + c), 0.0)
}

///|
test "binary64 runtime facade preserves IEEE division and signed zero" {
  let one = @float64.from_bits(0x3ff0000000000000UL)
  let negative_zero = @float64.from_bits(0x8000000000000000UL)
  assert_eq(
    @float64.to_bits(@float64.div(one, negative_zero)),
    0xfff0000000000000UL,
  )
  assert_eq(
    @float64.to_bits(@float64.sqrt(negative_zero)),
    0x8000000000000000UL,
  )
  assert_true(@float64.matches(@float64.div(0.0, 0.0), AnyNaN))
}
