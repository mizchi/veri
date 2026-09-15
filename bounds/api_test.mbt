///|
test "inclusive clamp agrees with core including a singleton interval" {
  for value in [-2147483648, -1, 0, 5, 10, 2147483647] {
    assert_eq(@bounds.clamp(value, 0, 10), value.clamp(min=0, max=10))
    assert_eq(@bounds.clamp(value, 5, 5), 5)
  }
}

///|
test "quickcheck: inclusive clamp agrees with the standard Int method" {
  @quickcheck.check(
    (input : (Int, Int, Int)) => {
      let (value, min, max) = input
      @bounds.clamp(value, min, max) == value.clamp(min~, max~)
    },
    filter=input => input.1 <= input.2,
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
}
