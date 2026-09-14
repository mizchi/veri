///|
test "minimum priority and duplicate preservation" {
  let original = @pqueue.push(@pqueue.empty(), 3)
  let queue = @pqueue.push(@pqueue.push(original, -1), 3)
  assert_eq(@pqueue.to_array(queue), [-1, 3, 3])
  assert_eq(@pqueue.to_array(original), [3])
  let (value, rest) = @pqueue.pop(queue).unwrap()
  assert_eq(value, -1)
  assert_eq(@pqueue.to_array(rest), [3, 3])
  assert_true(@pqueue.pop(@pqueue.empty()) is None)
}

///|
test "quickcheck: minimum queue traces agree with sorting and core PriorityQueue" {
  @quickcheck.check(
    (operations : Array[@commands.Command]) => {
      let mut queue = @pqueue.empty()
      let reference : Array[Int] = []
      let core : @core_pqueue.PriorityQueue[@cmp.Reverse[Int]] = @core_pqueue.PriorityQueue([],
      )
      for operation in operations {
        let before = queue
        let snapshot = @pqueue.to_array(before)
        match operation {
          Push(value) => {
            queue = @pqueue.push(queue, value)
            reference.push(value)
            reference.sort()
            core.push(@cmp.Reverse(value))
          }
          Pop => {
            let expected = if reference.is_empty() {
              None
            } else {
              Some(reference.remove(0))
            }
            let native = core.pop().map(value => value.0)
            if native != expected {
              return false
            }
            match @pqueue.pop(queue) {
              None => if expected is Some(_) { return false }
              Some((value, rest)) => {
                if Some(value) != expected {
                  return false
                }
                queue = rest
              }
            }
          }
          Peek => ()
          Clear => {
            queue = @pqueue.empty()
            reference.clear()
            core.clear()
          }
        }
        if @pqueue.to_array(queue) != reference ||
          @pqueue.peek(queue) != reference.get(0) ||
          @pqueue.is_empty(queue) != reference.is_empty() ||
          @pqueue.to_array(before) != snapshot {
          return false
        }
      }
      true
    },
    count=1000,
    max_size=128,
    max_shrinks=1000,
    seed=20260914,
  )
}

///|
test "ascending insertion scales without a linear recursive spine" {
  let mut queue = @pqueue.empty()
  for value in 0..<12000 {
    queue = @pqueue.push(queue, value)
  }
  for value in 0..<12000 {
    let (actual, rest) = @pqueue.pop(queue).unwrap()
    assert_eq(actual, value)
    queue = rest
  }
  assert_true(@pqueue.is_empty(queue))
}
