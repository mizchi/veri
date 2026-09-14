///|
test "safe reads include both bounds and extreme indices" {
  let xs : FixedArray[Int] = [10, 20]
  assert_eq(@array.get(xs, -1), None)
  assert_eq(@array.get(xs, 0), Some(10))
  assert_eq(@array.get(xs, 1), Some(20))
  assert_eq(@array.get(xs, 2), None)
  assert_eq(@array.get(xs, -2147483648), None)
  assert_eq(@array.get(xs, 2147483647), None)
  assert_eq(@array.get(FixedArray::make(0, 0), 0), None)
}

///|
test "reads observe mutations and work with non-integer elements" {
  let xs : FixedArray[String] = ["before", "other"]
  xs[0] = "after"
  assert_eq(@array.get(xs, 0), Some("after"))
  assert_eq(@array.get(xs, 1), Some("other"))
}
