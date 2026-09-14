///|
test "binary32 matching keeps signed zero and rejects a one-ULP error" {
  assert_true(@float32.matches(@float32.from_bits(0U), Bits(0U)))
  assert_true(
    @float32.matches(@float32.from_bits(0x80000000U), Bits(0x80000000U)),
  )
  assert_false(@float32.matches(@float32.from_bits(0x80000000U), Bits(0U)))
  assert_false(
    @float32.matches(@float32.from_bits(0x3f800000U), Bits(0x3f800001U)),
  )
  assert_true(@float32.matches(@float32.from_bits(0x7fc00001U), AnyNaN))
  assert_false(@float32.matches(@float32.from_bits(0x7f800000U), AnyNaN))
}

///|
test "each binary32 addition rounds before the next operation" {
  let a = @float32.from_bits(0x4b800000U)
  let b = @float32.from_bits(0xcb800000U)
  let c = @float32.from_bits(0x3f000000U)
  assert_eq(@float32.to_bits(@float32.add(@float32.add(a, b), c)), 0x3f000000U)
  assert_eq(@float32.to_bits(@float32.add(a, @float32.add(b, c))), 0U)
}
