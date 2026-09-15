///|
fn agrees(actual : Int64?, expected : @bigint.BigInt) -> Bool {
  let valid = expected >= @bigint.BigInt::from_int64(-9223372036854775808L) &&
    expected <= @bigint.BigInt::from_int64(9223372036854775807L)
  match actual {
    None => !valid
    Some(value) => valid && @bigint.BigInt::from_int64(value) == expected
  }
}

///|
test "quickcheck: checked arithmetic agrees with arbitrary precision" {
  @quickcheck.check(
    (input : (Int64, Int64)) => {
      let (x, y) = input
      let a = @bigint.BigInt::from_int64(x)
      let b = @bigint.BigInt::from_int64(y)
      agrees(@int64.checked_add(x, y), a + b) &&
      agrees(@int64.checked_sub(x, y), a - b) &&
      agrees(@int64.checked_mul(x, y), a * b)
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "checked arithmetic inputs use the core tuple shrinker" {
  let input : (Int64, Int64) = (123L, -456L)
  assert_true(@shrink.Shrink::shrink(input).any(x => x.0 == 0L))
  assert_true(@shrink.Shrink::shrink(input).any(x => x.1 == 0L))
}
