///|
test "relaxation accepts overflowing detours and rejects negative labels" {
  assert_true(@checker.relaxation(2147483647, 2147483647, 1))
  assert_false(@checker.relaxation(0, 2, 1))
  assert_false(@checker.relaxation(-1, 0, 1))
  assert_false(@checker.relaxation(0, -1, 1))
  assert_false(@checker.relaxation(0, 0, -1))
}

///|
test "quickcheck: relaxation agrees with widened arithmetic" {
  @quickcheck.check(
    (input : (Int, Int, Int)) => {
      let (cost, next, weight) = input
      @checker.relaxation(cost, next, weight) ==
      (
        cost >= 0 &&
        next >= 0 &&
        weight >= 0 &&
        next.to_int64() <= cost.to_int64() + weight.to_int64()
      )
    },
    count=1000,
    max_shrinks=1000,
    seed=20260923,
  )
}
