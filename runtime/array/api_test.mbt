///|
test "blit handles the same array with overlap in either direction" {
  let right : FixedArray[Int] = [0, 1, 2, 3]
  assert_true(@array.blit(right, right, { start: 0, count: 3, }, 1))
  assert_eq(right, [0, 0, 1, 2])
  let left : FixedArray[Int] = [0, 1, 2, 3]
  assert_true(@array.blit(left, left, { start: 1, count: 3, }, 0))
  assert_eq(left, [1, 2, 3, 3])
}
