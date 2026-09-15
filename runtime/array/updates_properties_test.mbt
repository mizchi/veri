///|
/// Independent range oracle: compute the endpoint in Int64, without subtraction.
fn reference_range(length : Int, start : Int, count : Int) -> Bool {
  0 <= start &&
  0 <= count &&
  start.to_int64() + count.to_int64() <= length.to_int64()
}

///|
/// Exercise nearby valid/invalid indices as well as full-width random integers.
fn nearby(value : Int, length : Int) -> Int {
  (value.reinterpret_as_uint() % (length + 2).reinterpret_as_uint()).reinterpret_as_int() -
  1
}

///|
/// Compare one transition against a snapshot, so overlapping copies cannot read
/// values that the reference itself has already overwritten.
fn update_step(
  actual : FixedArray[Int],
  expected : Array[Int],
  tag : Int,
  x : Int,
  y : Int,
  z : Int,
) -> Bool {
  let before = expected.copy()
  let n = before.length()
  let (ok, valid) = match tag {
    0 => {
      let valid = reference_range(n, x, 1)
      if valid {
        expected[x] = y
      }
      (@array.set(actual, x, y), valid)
    }
    1 => {
      let valid = reference_range(n, x, 1) && reference_range(n, y, 1)
      if valid {
        expected[x] = before[y]
        expected[y] = before[x]
      }
      (@array.swap(actual, x, y), valid)
    }
    2 => {
      let valid = reference_range(n, x, y)
      if valid {
        for i in 0..<n {
          if x <= i && i.to_int64() < x.to_int64() + y.to_int64() {
            expected[i] = z
          }
        }
      }
      (@array.fill(actual, z, { start: x, count: y, }), valid)
    }
    _ => {
      let valid = reference_range(n, x, z) && reference_range(n, y, z)
      if valid {
        for i in 0..<n {
          if y <= i && i.to_int64() < y.to_int64() + z.to_int64() {
            expected[i] = before[x + (i - y)]
          }
        }
      }
      (
        if tag == 3 {
          @array.copy_within(actual, { start: x, count: z, }, y)
        } else {
          @array.blit(actual, actual, { start: x, count: z, }, y)
        },
        valid,
      )
    }
  }
  ok == valid && actual.length() == n && actual.iter().to_array() == expected
}

///|
fn update_case(
  original : FixedArray[Int],
  tag : Int,
  x : Int,
  y : Int,
  z : Int,
) -> Bool {
  let actual = FixedArray::makei(original.length(), i => original[i])
  update_step(actual, original.iter().to_array(), tag, x, y, z)
}

///|
test "quickcheck: range validation agrees with widened endpoint arithmetic" {
  @quickcheck.check(
    (input : (Int, Int, Int)) => {
      let (length, start, count) = input
      @array.valid_range(length, { start, count, }) ==
      reference_range(length, start, count)
    },
    count=1000,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: set preserves every other cell and rejects invalid indices" {
  @quickcheck.check(
    (input : (FixedArray[Int], Int, Int)) => {
      let (original, index, value) = input
      update_case(original, 0, index, value, 0) &&
      update_case(original, 0, nearby(index, original.length()), value, 0)
    },
    count=1000,
    max_size=64,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: swap matches a snapshot including equal indices" {
  @quickcheck.check(
    (input : (FixedArray[Int], Int, Int)) => {
      let (original, left, right) = input
      let i = nearby(left, original.length())
      let j = nearby(right, original.length())
      update_case(original, 1, left, right, 0) &&
      update_case(original, 1, i, j, 0) &&
      update_case(original, 1, i, i, 0)
    },
    count=1000,
    max_size=64,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: fill changes exactly its range and invalid fills are atomic" {
  @quickcheck.check(
    (input : (FixedArray[Int], Int, Int, Int)) => {
      let (original, start, count, value) = input
      update_case(original, 2, start, count, value) &&
      update_case(
        original,
        2,
        nearby(start, original.length()),
        nearby(count, original.length()),
        value,
      )
    },
    count=1000,
    max_size=64,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: copy_within matches immutable source values for overlapping ranges" {
  @quickcheck.check(
    (input : (FixedArray[Int], Int, Int, Int)) => {
      let (original, source, target, count) = input
      let n = original.length()
      update_case(original, 3, source, target, count) &&
      update_case(
        original,
        3,
        nearby(source, n),
        nearby(target, n),
        nearby(count, n),
      ) &&
      update_case(original, 3, 0, 1, n - 1) &&
      update_case(original, 3, 1, 0, n - 1)
    },
    count=1000,
    max_size=64,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
fn blit_case(
  source : FixedArray[Int],
  original : FixedArray[Int],
  src : Int,
  dst : Int,
  count : Int,
) -> Bool {
  let source_before = source.iter().to_array()
  // Clone both inputs so even a broken implementation cannot mutate the
  // generated values that QuickCheck reuses during replay and shrinking.
  let actual_source = FixedArray::makei(source.length(), i => source[i])
  let target = FixedArray::makei(original.length(), i => original[i])
  let expected = original.iter().to_array()
  let valid = reference_range(source.length(), src, count) &&
    reference_range(target.length(), dst, count)
  if valid {
    for i in 0..<expected.length() {
      if dst <= i && i.to_int64() < dst.to_int64() + count.to_int64() {
        expected[i] = source_before[src + (i - dst)]
      }
    }
  }
  @array.blit(actual_source, target, { start: src, count, }, dst) == valid &&
  actual_source.iter().to_array() == source_before &&
  target.iter().to_array() == expected
}

///|
test "quickcheck: blit preserves its source and destination frame" {
  @quickcheck.check(
    (input : (FixedArray[Int], FixedArray[Int], Int, Int, Int)) => {
      let (source, target, src, dst, count) = input
      blit_case(source, target, src, dst, count) &&
      blit_case(
        source,
        target,
        nearby(src, source.length()),
        nearby(dst, target.length()),
        nearby(count, source.length()),
      )
    },
    count=1000,
    max_size=64,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "quickcheck: update traces agree with a snapshot model after every operation" {
  @quickcheck.check(
    (input : (FixedArray[Int], Array[(Int, Int, Int, Int)])) => {
      let (original, trace) = input
      let actual = FixedArray::makei(original.length(), i => original[i])
      let expected = original.iter().to_array()
      for (kind, x, y, z) in trace {
        let tag = (kind.reinterpret_as_uint() % 4U).reinterpret_as_int()
        let n = original.length()
        guard update_step(
          actual,
          expected,
          tag,
          nearby(x, n),
          if tag == 0 {
            y
          } else {
            nearby(y, n)
          },
          if tag == 3 {
            nearby(z, n)
          } else {
            z
          },
        ) else {
          return false
        }
      }
      true
    },
    count=1000,
    max_size=64,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "array update inputs use core tuple and array shrinking" {
  let input : (FixedArray[Int], Int, Int) = ([10, 20], 1, 2)
  assert_true(
    @shrink.Shrink::shrink(input).any(candidate => candidate.0.length() == 0),
  )
  assert_true(@shrink.Shrink::shrink(input).any(candidate => candidate.1 == 0))
  assert_true(@shrink.Shrink::shrink(input).any(candidate => candidate.2 == 0))
}

///|
test "quickcheck: a wrong forward copy shrinks to a three-cell overlap" {
  let report = @quickcheck.report(
    (original : FixedArray[Int]) => {
      if original.length() < 3 {
        return true
      }
      let broken = FixedArray::makei(original.length(), i => original[i])
      // Deliberately wrong: the next source cell was already overwritten.
      for i in 1..<broken.length() {
        broken[i] = broken[i - 1]
      }
      for i in 1..<broken.length() {
        if broken[i] != original[i - 1] {
          return false
        }
      }
      true
    },
    counterexample_context=xs => "length=\{xs.length()}",
    count=1000,
    max_size=64,
    max_shrinks=1000,
    seed=20260914,
  )
  let rendered = @debug.to_string(report)
  assert_true(rendered.has_prefix("Falsified("))
  assert_true(rendered.contains("length=3"))
}

///|
test "quickcheck: alias-aware blit matches snapshots for valid and invalid overlaps" {
  @quickcheck.check(
    (input : (FixedArray[Int], Int, Int, Int)) => {
      let (original, source, target, count) = input
      let n = original.length()
      update_case(original, 4, source, target, count) &&
      update_case(
        original,
        4,
        nearby(source, n),
        nearby(target, n),
        nearby(count, n),
      ) &&
      update_case(original, 4, 0, 1, n - 1) &&
      update_case(original, 4, 1, 0, n - 1) &&
      update_case(original, 4, n, n, 0)
    },
    count=1000,
    max_size=64,
    max_shrinks=1000,
    seed=20260915,
  )
}
