///|
test "input minimization preserves failure and rejects cycles" {
  let result = @model_check.minimize(
    100,
    x => x >= 3,
    candidates=x => [x, x + 1, 0, x / 2, x - 1].iter(),
    cost=x => x,
    max_attempts=100,
  )
  assert_eq(result.value, 3)
  assert_true(result.attempts <= 100)
  let limited = @model_check.minimize(
    100,
    x => x >= 3,
    candidates=x => [x - 1].iter(),
    cost=x => x,
    max_attempts=2,
  )
  assert_eq(limited.value, 98)
  assert_true(limited.exhausted)
}
