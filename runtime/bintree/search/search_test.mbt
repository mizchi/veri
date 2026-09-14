///|
test "quickcheck: search-tree insertion preserves sorted unique contents" {
  @quickcheck.check(
    (input : (Array[Int], Int)) => {
      let mut tree : @tree.Tree[Int] = @tree.Empty
      let expected : Array[Int] = []
      for value in input.0 {
        let before = tree
        let snapshot = @linked.to_array(@tree.inorder(before))
        tree = @search.insert(tree, value)
        if !expected.contains(value) {
          expected.push(value)
        }
        expected.sort()
        if @linked.to_array(@tree.inorder(tree)) != expected ||
          @linked.to_array(@tree.inorder(before)) != snapshot ||
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
