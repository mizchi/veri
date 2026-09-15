///|
test "range validation includes empty endpoints and full Int limits" {
  assert_true(@array.valid_range(0, { start: 0, count: 0, }))
  assert_true(@array.valid_range(2147483647, { start: 0, count: 2147483647, }))
  assert_true(@array.valid_range(2147483647, { start: 2147483647, count: 0, }))
  assert_false(@array.valid_range(2147483647, { start: 2147483647, count: 1, }))
  assert_false(@array.valid_range(2147483647, { start: 1, count: 2147483647, }))
  assert_false(@array.valid_range(-1, { start: 0, count: 0, }))
  assert_false(@array.valid_range(0, { start: -2147483648, count: 0, }))
  assert_false(@array.valid_range(0, { start: 0, count: -2147483648, }))
}

///|
test "set validates the index before changing a cell" {
  let xs : FixedArray[Int] = [10, 20, 30]
  assert_true(@array.set(xs, 1, 99))
  assert_eq(xs, [10, 99, 30])
  for i in [-1, 3, -2147483648, 2147483647] {
    assert_false(@array.set(xs, i, 0))
    assert_eq(xs, [10, 99, 30])
  }
  assert_false(@array.set(FixedArray::make(0, 0), 0, 1))
}

///|
test "swap checks both indices and permits the same index" {
  let xs : FixedArray[String] = ["a", "b", "c"]
  assert_true(@array.swap(xs, 0, 2))
  assert_eq(xs, ["c", "b", "a"])
  assert_true(@array.swap(xs, 1, 1))
  for (i, j) in [(0, 3), (-1, 1), (2147483647, 0)] {
    assert_false(@array.swap(xs, i, j))
    assert_eq(xs, ["c", "b", "a"])
  }
}

///|
test "fill uses start and count and leaves invalid ranges untouched" {
  let xs : FixedArray[Int] = [0, 1, 2, 3, 4]
  assert_true(@array.fill(xs, 9, { start: 1, count: 3, }))
  assert_eq(xs, [0, 9, 9, 9, 4])
  assert_true(@array.fill(xs, 7, { start: 5, count: 0, }))
  for
    (start, count) in [
      (-1, 0),
      (0, -1),
      (6, 0),
      (4, 2),
      (2147483647, 1),
      (1, 2147483647),
    ] {
    assert_false(@array.fill(xs, 7, { start, count, }))
    assert_eq(xs, [0, 9, 9, 9, 4])
  }
  assert_true(@array.fill(FixedArray::make(0, 0), 1, { start: 0, count: 0, }))
}

///|
test "blit preserves source and destination cells outside the target range" {
  let source : FixedArray[Int] = [10, 20, 30, 40]
  let target : FixedArray[Int] = [0, 1, 2, 3, 4]
  assert_true(@array.blit(source, target, { start: 1, count: 2, }, 2))
  assert_eq(source, [10, 20, 30, 40])
  assert_eq(target, [0, 1, 20, 30, 4])
  assert_true(@array.blit(source, target, { start: 4, count: 0, }, 5))
  for
    (src, dst, count) in [
      (3, 0, 2),
      (0, 4, 2),
      (-1, 0, 0),
      (0, -1, 0),
      (0, 0, -1),
      (1, 1, 2147483647),
    ] {
    assert_false(@array.blit(source, target, { start: src, count, }, dst))
    assert_eq(source, [10, 20, 30, 40])
    assert_eq(target, [0, 1, 20, 30, 4])
  }
}

///|
test "copy_within handles overlap in both directions without a temporary array" {
  let right : FixedArray[Int] = [0, 1, 2, 3, 4]
  assert_true(@array.copy_within(right, { start: 0, count: 4, }, 1))
  assert_eq(right, [0, 0, 1, 2, 3])
  let left : FixedArray[Int] = [0, 1, 2, 3, 4]
  assert_true(@array.copy_within(left, { start: 1, count: 4, }, 0))
  assert_eq(left, [1, 2, 3, 4, 4])
  assert_true(@array.copy_within(left, { start: 1, count: 3, }, 1))
  assert_eq(left, [1, 2, 3, 4, 4])
  assert_true(@array.copy_within(left, { start: 5, count: 0, }, 5))
  for
    (src, dst, count) in [
      (4, 0, 2),
      (0, 4, 2),
      (-1, 0, 0),
      (0, 0, -1),
      (0, 1, 2147483647),
    ] {
    assert_false(@array.copy_within(left, { start: src, count, }, dst))
    assert_eq(left, [1, 2, 3, 4, 4])
  }
}
