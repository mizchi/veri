///|
test "quickcheck: wrapping arithmetic agrees with native UInt64" {
  @quickcheck.check(
    (input : (UInt64, UInt64)) => {
      let (x, y) = input
      @uint64.add(x, y) == x + y && @uint64.sub(x, y) == x - y
    },
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: wrapping addition and subtraction are inverses" {
  @quickcheck.check(
    (input : (UInt64, UInt64)) => {
      let (x, y) = input
      @uint64.sub(@uint64.add(x, y), y) == x &&
      @uint64.add(@uint64.sub(x, y), y) == x
    },
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: unsigned order agrees with sign-bit biased signed order" {
  @quickcheck.check(
    (input : (UInt64, UInt64)) => {
      let (x, y) = input
      let signed_x = (x ^ 0x8000000000000000UL).reinterpret_as_int64()
      let signed_y = (y ^ 0x8000000000000000UL).reinterpret_as_int64()
      @uint64.less(x, y) == (signed_x < signed_y)
    },
    count=1000,
    seed=20260914,
  )
}
