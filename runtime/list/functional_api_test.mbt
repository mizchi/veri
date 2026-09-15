///|
priv suberror Stop {
  Stop(Int)
}

///|
test "core fold labels and iterator construction" {
  let xs = @list.List::from_iter([1, 2, 3].iter())
  assert_eq(xs.fold(init="", (acc, x) => acc + x.to_string()), "123")
  assert_eq(
    @list.List::from_iter(Iter::empty()).fold(init=7, (a, b : Int) => a + b),
    7,
  )
}

///|
test "map and fold propagate callback errors without visiting later elements" {
  let xs = @list.List::from_array([1, 2, 3])
  let seen = []
  try
    xs.map(x => {
      seen.push(x)
      if x == 2 {
        raise Stop(x)
      }
      x * 2
    })
  catch {
    Stop(x) => assert_eq(x, 2)
  } noraise {
    _ => fail("map must propagate the callback error")
  }
  assert_eq(seen, [1, 2])
  seen.clear()
  try
    xs.fold(init=10, (acc, x) => {
      seen.push(x)
      if x == 2 {
        raise Stop(acc)
      }
      acc + x
    })
  catch {
    Stop(x) => assert_eq(x, 11)
  } noraise {
    _ => fail("fold must propagate the callback error")
  }
  assert_eq(seen, [1, 2])
  assert_eq(xs.to_array(), [1, 2, 3])
}
