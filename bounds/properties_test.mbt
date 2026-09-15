///|
test "quickcheck: clamp preserves the interval and is idempotent" {
  @quickcheck.check(
    (input : (Int, Int, Int)) => {
      let (value, lower, upper) = input
      let result = @bounds.clamp_half_open(value, lower, upper)
      lower <= result &&
      result < upper &&
      (value < lower || value >= upper || result == value) &&
      @bounds.clamp_half_open(result, lower, upper) == result
    },
    filter=input => input.1 < input.2,
    count=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: clamp is monotone" {
  @quickcheck.check(
    (input : (Int, Int, Int, Int)) => {
      let (x, y, lower, upper) = input
      @bounds.clamp_half_open(x, lower, upper) <=
      @bounds.clamp_half_open(y, lower, upper)
    },
    filter=input => input.0 <= input.1 && input.2 < input.3,
    count=1000,
    seed=20260914,
  )
}
