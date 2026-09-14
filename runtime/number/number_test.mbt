///|
test "gcd handles zeros, common factors, coprimes and full width" {
  assert_eq(@number.gcd(0U, 0U), 0U)
  assert_eq(@number.gcd(42U, 0U), 42U)
  assert_eq(@number.gcd(0U, 42U), 42U)
  assert_eq(@number.gcd(48U, 18U), 6U)
  assert_eq(@number.gcd(17U, 31U), 1U)
  assert_eq(@number.gcd(0xffffffffU, 0U), 0xffffffffU)
  assert_eq(@number.gcd(0xffffffffU, 0xfffffffeU), 1U)
}

///|
test "division conventions and rejected inputs" {
  assert_eq(@number.div_rem(-7, 3), Some((-2, -1)))
  assert_eq(@number.div_rem(7, -3), Some((-2, 1)))
  assert_eq(@number.div_rem(-7, -3), Some((2, -1)))
  assert_eq(@number.div_rem(-2147483648, 1), Some((-2147483648, 0)))
  assert_eq(@number.div_rem(-2147483648, -1), None)
  assert_eq(@number.div_rem(1, 0), None)
  assert_eq(@number.euclidean_mod(-7, 3), Some(2))
  assert_eq(@number.euclidean_mod(-2147483648, 2147483647), Some(2147483646))
  assert_eq(@number.euclidean_mod(-2147483648, 1), Some(0))
  assert_eq(@number.euclidean_mod(1, 0), None)
  assert_eq(@number.euclidean_mod(1, -1), None)
}

///|
/// Independent bounded oracle: enumerate common divisors, without Euclid's step.
fn trial_gcd(x : UInt, y : UInt) -> UInt {
  let mut result = 0U
  let bound = if x > y { x } else { y }
  for divisor = 1U; divisor <= bound; divisor = divisor + 1U {
    if x % divisor == 0U && y % divisor == 0U {
      result = divisor
    }
  }
  result
}

///|
test "quickcheck: gcd agrees with enumerated common divisors" {
  @quickcheck.check(
    (input : (UInt, UInt)) => {
      let (x, y) = input
      let a = x % 257U
      let b = y % 257U
      @number.gcd(a, b) == trial_gcd(a, b)
    },
    count=1000,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: full-width gcd is a symmetric common divisor" {
  @quickcheck.check(
    (input : (UInt, UInt)) => {
      let (x, y) = input
      let d = @number.gcd(x, y)
      d == @number.gcd(y, x) &&
      (if d == 0U { x == 0U && y == 0U } else { x % d == 0U && y % d == 0U })
    },
    count=1000,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: signed division decomposes in Int64 without overflow" {
  @quickcheck.check(
    (input : (Int, Int)) => {
      let (x, y) = input
      match @number.div_rem(x, y) {
        None => y == 0 || (x == -2147483648 && y == -1)
        Some((q, r)) => {
          let a = x.to_int64()
          let b = y.to_int64()
          let remainder = r.to_int64()
          a == b * q.to_int64() + remainder &&
          remainder.abs() < b.abs() &&
          (r == 0 || (r < 0) == (x < 0))
        }
      }
    },
    count=1000,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: Euclidean remainder is the unique nonnegative representative" {
  @quickcheck.check(
    (input : (Int, Int)) => {
      let (x, m) = input
      match @number.euclidean_mod(x, m) {
        None => m <= 0
        Some(r) =>
          m > 0 &&
          0 <= r &&
          r < m &&
          (x.to_int64() - r.to_int64()) % m.to_int64() == 0L
      }
    },
    count=1000,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "numeric tuple shrinker reaches the zero boundary" {
  let values = @shrink.Shrink::shrink((42U, 18U)).to_array()
  assert_true(values.contains((0U, 18U)))
  assert_true(values.contains((42U, 0U)))
}
