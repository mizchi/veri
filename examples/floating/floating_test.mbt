///|
test "binary32 and binary64 round at their own precision" {
  let one = @float32.from_bits(0x3f800000U)
  let half_ulp = @float32.from_bits(0x33800000U)
  let single = @float32.add(one, half_ulp)
  assert_true(@float32.matches(single, Bits(0x3f800000U)))
  let double = @float64.add(
    @float32.to_double(one),
    @float32.to_double(half_ulp),
  )
  assert_true(@float64.matches(double, Bits(0x3ff0000010000000UL)))
  assert_true(@float32.matches(@float64.to_float(double), Bits(0x3f800000U)))
}
