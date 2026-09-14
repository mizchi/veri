///|
test "quickcheck: Float widening roundtrip preserves non-NaN bits" {
  @quickcheck.check(
    (bits : UInt) => {
      let value = @float32.from_bits(bits)
      let widened = @float32.to_double(value)
      let restored = @float64.to_float(widened)
      if @float32.is_nan(value) {
        @float64.is_nan(widened) && @float32.is_nan(restored)
      } else {
        @float32.to_bits(restored) == bits
      }
    },
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: narrowing is stable after widening its result" {
  @quickcheck.check(
    (bits : UInt64) => {
      let narrowed = @float64.to_float(@float64.from_bits(bits))
      let restored = @float64.to_float(@float32.to_double(narrowed))
      if @float32.is_nan(narrowed) {
        @float32.is_nan(restored)
      } else {
        @float32.to_bits(restored) == @float32.to_bits(narrowed)
      }
    },
    count=1000,
    seed=20260914,
  )
}
