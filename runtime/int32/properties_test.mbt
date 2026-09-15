///|
fn agrees(actual : Int?, expected : @bigint.BigInt) -> Bool {
  let valid = expected >= @bigint.BigInt::from_int(-2147483648) &&
    expected <= @bigint.BigInt::from_int(2147483647)
  match actual {
    None => !valid
    Some(value) => valid && @bigint.BigInt::from_int(value) == expected
  }
}

///|
test "quickcheck: checked arithmetic agrees with arbitrary precision" {
  @quickcheck.check(
    (input : (Int, Int)) => {
      let (x, y) = input
      let a = @bigint.BigInt::from_int(x)
      let b = @bigint.BigInt::from_int(y)
      agrees(@int32.checked_add(x, y), a + b) &&
      agrees(@int32.checked_sub(x, y), a - b) &&
      agrees(@int32.checked_mul(x, y), a * b)
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "checked arithmetic inputs use the core tuple shrinker" {
  let input : (Int, Int) = (123, -456)
  assert_true(@shrink.Shrink::shrink(input).any(x => x.0 == 0))
  assert_true(@shrink.Shrink::shrink(input).any(x => x.1 == 0))
}
