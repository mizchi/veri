///|
test "quickcheck: wrapping arithmetic agrees with native UInt" {
  @quickcheck.check(
    (input : (UInt, UInt)) => {
      let (x, y) = input
      @uint32.add(x, y) == x + y && @uint32.sub(x, y) == x - y
    },
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: wrapping addition and subtraction are inverses" {
  @quickcheck.check(
    (input : (UInt, UInt)) => {
      let (x, y) = input
      @uint32.sub(@uint32.add(x, y), y) == x &&
      @uint32.add(@uint32.sub(x, y), y) == x
    },
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: unsigned order agrees with sign-bit biased signed order" {
  @quickcheck.check(
    (input : (UInt, UInt)) => {
      let (x, y) = input
      let signed_x = (x ^ 0x80000000U).reinterpret_as_int()
      let signed_y = (y ^ 0x80000000U).reinterpret_as_int()
      @uint32.less(x, y) == (signed_x < signed_y)
    },
    count=1000,
    seed=20260914,
  )
}
