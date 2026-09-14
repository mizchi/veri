///|
test "quickcheck: safe reads match every cell and reject invalid indices" {
  @quickcheck.check(
    (input : (FixedArray[Int], Int)) => {
      let (xs, index) = input
      let expected = if 0 <= index && index < xs.length() {
        Some(xs[index])
      } else {
        None
      }
      // Visit all valid cells as well: full-width indices are usually invalid.
      let mut cells_match = true
      for i in 0..<xs.length() {
        cells_match = cells_match && @array.get(xs, i) == Some(xs[i])
      }
      cells_match &&
      @array.get(xs, index) == expected &&
      @array.get(xs, -1) == None &&
      @array.get(xs, xs.length()) == None
    },
    count=1000,
    max_size=64,
    seed=20260914,
  )
}

///|
test "quickcheck: reads observe a write and preserve other cells" {
  @quickcheck.check(
    (input : (FixedArray[Int], UInt, Int)) => {
      let (original, position, value) = input
      // Keep generated input immutable so replay and shrinking see the same data.
      let xs = FixedArray::makei(original.length(), i => original[i])
      let index = (position % xs.length().reinterpret_as_uint()).reinterpret_as_int()
      xs[index] = value
      let mut agrees = true
      for i in 0..<xs.length() {
        let expected = if i == index { value } else { original[i] }
        agrees = agrees && @array.get(xs, i) == Some(expected)
      }
      agrees
    },
    filter=input => input.0.length() > 0,
    count=1000,
    max_size=64,
    seed=20260914,
  )
}
