///|
test "bounds include duplicates and empty arrays" {
  let xs : FixedArray[Int] = [1, 2, 2, 4]
  assert_eq(@search.lower_bound(xs, 2), 1)
  assert_eq(@search.upper_bound(xs, 2), 3)
  assert_eq(@search.lower_bound(xs, 3), 3)
  assert_eq(@search.upper_bound(xs, 4), 4)
  assert_eq(@search.lower_bound([], 0), 0)
  assert_eq(@search.upper_bound([], 0), 0)
  assert_true(@search.is_sorted(xs))
  assert_false(@search.is_sorted([2, 1]))
  assert_true(@search.check_sort([2, 1, 2], [1, 2, 2]))
  assert_false(@search.check_sort([2, 1, 2], [1, 1, 2]))
  assert_false(@search.check_sort([2, 1, 2], [2, 1, 2]))
}

///|
test "quickcheck: bounds match linear counts and core sorting preserves multiplicity" {
  @quickcheck.check(
    (input : (Array[Int], Int)) => {
      let (before, key) = input
      let sorted = before.copy()
      sorted.sort()
      let fixed = FixedArray::from_array(sorted)
      @search.is_sorted(fixed) &&
      @search.lower_bound(fixed, key) ==
      sorted.iter().filter(x => x < key).count() &&
      @search.upper_bound(fixed, key) ==
      sorted.iter().filter(x => x <= key).count() &&
      @search.check_sort(before[:], sorted[:])
    },
    count=500,
    max_size=64,
    max_shrinks=1000,
    seed=20260919,
  )
}

///|
test "Int endpoints and incorrect multiplicities" {
  let xs : FixedArray[Int] = [-2147483648, -2147483648, 0, 2147483647]
  assert_true(@search.is_sorted(xs))
  assert_eq(@search.lower_bound(xs, -2147483648), 0)
  assert_eq(@search.upper_bound(xs, -2147483648), 2)
  assert_eq(@search.lower_bound(xs, 2147483647), 3)
  assert_eq(@search.upper_bound(xs, 2147483647), 4)
  assert_true(@search.check_sort([], []))
  assert_false(@search.check_sort([1], []))
}
