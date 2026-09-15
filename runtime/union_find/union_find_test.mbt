///|
test "union, sizes, copies and rejected indices" {
  let uf = try! @union_find.UnionFind::new(4)
  assert_eq(uf.length(), 4)
  assert_eq(uf.component_count(), 4)
  assert_true(try! uf.union(0, 1))
  assert_false(try! uf.union(1, 0))
  assert_true(try! uf.same(0, 1))
  assert_eq(try! uf.component_size(1), 2)
  assert_eq(uf.component_count(), 3)
  let copy = uf.copy()
  assert_true(try! copy.union(1, 2))
  assert_false(try! uf.same(0, 2))
  assert_true(
    try {
      ignore(uf.union(0, 4))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(uf.find(-1))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@union_find.UnionFind::new(-1))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(uf.component_count(), 3)
  let empty = try! @union_find.UnionFind::new(0)
  assert_eq(empty.to_array(), [])
}

///|
test "quickcheck: union-find traces preserve exactly the reference partition" {
  @quickcheck.check(
    (input : (Int, Array[(Int, Int)])) => {
      let (tag, commands) = input
      let n = (tag % 12).abs() + 1
      let uf = try! @union_find.UnionFind::new(n)
      let labels = Array::makei(n, i => i)
      for (a, b) in commands {
        let left = (a % n).abs()
        let right = (b % n).abs()
        let l = labels[left]
        let r = labels[right]
        if (try! uf.union(left, right)) != (l != r) {
          return false
        }
        for i = 0; i < n; i = i + 1 {
          if labels[i] == r {
            labels[i] = l
          }
        }
        let reps = uf.to_array()
        let mut count = 0
        for i = 0; i < n; i = i + 1 {
          if labels[i] == i {
            count += 1
          }
          if (try! uf.find(reps[i])) != reps[i] {
            return false
          }
          let mut size = 0
          for j = 0; j < n; j = j + 1 {
            let expected = labels[i] == labels[j]
            if expected {
              size += 1
            }
            if (try! uf.same(i, j)) != expected ||
              (reps[i] == reps[j]) != expected {
              return false
            }
          }
          if (try! uf.component_size(i)) != size {
            return false
          }
        }
        if uf.component_count() != count {
          return false
        }
      }
      true
    },
    count=500,
    max_size=64,
    max_shrinks=1000,
    seed=20260922,
  )
}
