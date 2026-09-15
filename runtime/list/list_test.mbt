///|
test "persistent list operations preserve their inputs" {
  let xs = @list.cons(1, @list.cons(2, @list.empty()))
  let ys = @list.cons(3, @list.empty())
  assert_eq(@list.to_array(@list.append(xs, ys)), [1, 2, 3])
  assert_eq(@list.to_array(@list.reverse(xs)), [2, 1])
  assert_eq(@list.to_array(xs), [1, 2])
  assert_eq(@list.length(xs), 2)
  let empty : @list.List[Int] = @list.empty()
  assert_true(@list.uncons(empty) is None)
}

///|
test "length handles a long list without recursive call-stack growth" {
  let values = Array::makei(20000, i => i)
  let xs = @list.from_array(values)
  assert_eq(@list.length(xs), values.length())
}

///|
test "quickcheck: persistent list append and reverse agree with arrays" {
  @quickcheck.check(
    (input : (Array[Int], Array[Int])) => {
      let (xs, ys) = input
      let left = @list.from_array(xs)
      let right = @list.from_array(ys)
      @list.to_array(@list.append(left, right)) == xs + ys &&
      @list.to_array(@list.reverse(left)) == xs.rev() &&
      left.iter().to_array() == xs &&
      @list.to_array(left) == xs &&
      @list.length(left) == xs.length()
    },
    count=1000,
    max_size=64,
    seed=20260914,
  )
}
