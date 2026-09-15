///|
test "quickcheck: search-tree insertion preserves sorted unique contents" {
  @quickcheck.check(
    (input : (Array[Int], Int)) => {
      let mut tree = @search.empty()
      let expected : Array[Int] = []
      for value in input.0 {
        let before = tree
        let snapshot = @search.to_array(before)
        tree = @search.insert(tree, value)
        if !expected.contains(value) {
          expected.push(value)
        }
        expected.sort()
        if tree.iter().to_array() != expected ||
          @search.to_array(tree) != expected ||
          @search.to_array(before) != snapshot ||
          !@search.contains(tree, value) {
          return false
        }
      }
      @search.contains(tree, input.1) == expected.contains(input.1)
    },
    count=1000,
    max_size=64,
    seed=20260914,
  )
}

///|
test "ascending search-tree insertion stays shallow" {
  let mut tree = @search.empty()
  for value in 0..<12000 {
    tree = @search.insert(tree, value)
  }
  assert_true(@search.contains(tree, 0))
  assert_true(@search.contains(tree, 11999))
  assert_false(@search.contains(tree, 12000))
}
