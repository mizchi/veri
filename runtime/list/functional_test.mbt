///|
test "map identity, composition and ordered fold" {
  let xs = @list.List::from_array([1, 2, 3][:])
  assert_eq(xs.map(x => x).to_array(), [1, 2, 3])
  assert_eq(
    xs.map(x => x + 1).map(x => x * 2).to_array(),
    xs.map(x => (x + 1) * 2).to_array(),
  )
  assert_eq(xs.fold(init=0, (sum, x) => sum + x), 6)
  assert_eq(xs.fold(init="", (s, x) => s + x.to_string()), "123")
}

///|
test "quickcheck: map laws and partitioned fold with core shrinking" {
  @quickcheck.check(
    (input : (Array[Int], Array[Int])) => {
      let (a, b) = input
      // Small exact sums; no dependence on overflow behavior for algebra laws.
      let xs = @list.List::from_array(a.map(x => x % 100))
      let ys = @list.List::from_array(b.map(x => x % 100))
      let add = (x, y) => x + y
      let left = xs.fold(init=0, add)
      let right = ys.fold(init=0, add)
      let core = @core_list.List::from_iter(a.map(x => x % 100).iter())
      xs.to_array() == core.to_array() &&
      xs.map(x => x * 2).to_array() == core.map(x => x * 2).to_array() &&
      left == core.fold(init=0, add) &&
      @list.List::from_iter(xs.iter()).to_array() == core.to_array() &&
      xs.map(x => x).to_array() == xs.to_array() &&
      xs.map(x => x + 1).map(x => x * 2).to_array() ==
      xs.map(x => (x + 1) * 2).to_array() &&
      xs.concat(ys).fold(init=0, add) == left + right &&
      xs.concat(ys).fold(init=0, add) == ys.fold(init=left, add) &&
      xs.concat(ys).fold(init=0, add) == ys.concat(xs).fold(init=0, add)
    },
    count=1000,
    max_size=64,
    max_shrinks=1000,
    seed=20260915,
  )
  assert_true(@shrink.Shrink::shrink([1, 2, 3]).any(xs => xs.is_empty()))
}

///|
test "map and fold invoke callbacks in order and handle long lists" {
  let xs = @list.List::from_array(Array::makei(20000, i => i))
  let seen = []
  let ys = xs.map(x => {
    seen.push(x)
    x + 1
  })
  assert_eq(seen, xs.to_array())
  assert_eq(ys.fold(init=0, (sum, _) => sum + 1), 20000)
  let zs = @list.List::from_array([1, 2, 3])
  assert_true(
    zs.fold(init=0, (a, b) => a - b) != zs.fold(init=0, (a, b) => b - a),
  )
}
