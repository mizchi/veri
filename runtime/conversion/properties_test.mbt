///|
fn matches_int(value : @bigint.BigInt, result : Int?) -> Bool {
  let valid = value >= @bigint.BigInt::from_int(-2147483648) &&
    value <= @bigint.BigInt::from_int(2147483647)
  match result {
    None => !valid
    Some(x) => valid && value == @bigint.BigInt::from_int(x)
  }
}

///|
fn matches_uint(value : @bigint.BigInt, result : UInt?) -> Bool {
  let valid = value >= @bigint.BigInt::from_uint(0U) &&
    value <= @bigint.BigInt::from_uint(4294967295U)
  match result {
    None => !valid
    Some(x) => valid && value == @bigint.BigInt::from_uint(x)
  }
}

///|
fn matches_int64(value : @bigint.BigInt, result : Int64?) -> Bool {
  let valid = value >= @bigint.BigInt::from_int64(-9223372036854775808L) &&
    value <= @bigint.BigInt::from_int64(9223372036854775807L)
  match result {
    None => !valid
    Some(x) => valid && value == @bigint.BigInt::from_int64(x)
  }
}

///|
fn matches_uint64(value : @bigint.BigInt, result : UInt64?) -> Bool {
  let valid = value >= @bigint.BigInt::from_uint64(0UL) &&
    value <= @bigint.BigInt::from_uint64(18446744073709551615UL)
  match result {
    None => !valid
    Some(x) => valid && value == @bigint.BigInt::from_uint64(x)
  }
}

///|
test "quickcheck: int conversions agree with arbitrary precision" {
  @quickcheck.check(
    (x : Int) => {
      let n = @bigint.BigInt::from_int(x)
      matches_uint(n, @conversion.checked_int_to_uint(x)) &&
      matches_int64(n, Some(@conversion.int_to_int64(x))) &&
      matches_uint64(n, @conversion.checked_int_to_uint64(x))
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "quickcheck: uint conversions agree with arbitrary precision" {
  @quickcheck.check(
    (x : UInt) => {
      let n = @bigint.BigInt::from_uint(x)
      matches_int(n, @conversion.checked_uint_to_int(x)) &&
      matches_int64(n, Some(@conversion.uint_to_int64(x))) &&
      matches_uint64(n, Some(@conversion.uint_to_uint64(x)))
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "quickcheck: int64 conversions agree with arbitrary precision" {
  @quickcheck.check(
    (x : Int64) => {
      let n = @bigint.BigInt::from_int64(x)
      matches_int(n, @conversion.checked_int64_to_int(x)) &&
      matches_uint(n, @conversion.checked_int64_to_uint(x)) &&
      matches_uint64(n, @conversion.checked_int64_to_uint64(x))
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "quickcheck: uint64 conversions agree with arbitrary precision" {
  @quickcheck.check(
    (x : UInt64) => {
      let n = @bigint.BigInt::from_uint64(x)
      matches_int(n, @conversion.checked_uint64_to_int(x)) &&
      matches_uint(n, @conversion.checked_uint64_to_uint(x)) &&
      matches_int64(n, @conversion.checked_uint64_to_int64(x))
    },
    count=1000,
    max_shrinks=1000,
    seed=20260915,
  )
}

///|
test "conversion inputs shrink toward zero" {
  assert_true(@shrink.Shrink::shrink(1234567890123456789L).any(x => x == 0L))
  assert_true(@shrink.Shrink::shrink(12345678901234567890UL).any(x => x == 0UL))
}
