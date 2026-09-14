///|
test "FIFO and persistent snapshots" {
  let empty : @queue.Queue[Int] = @queue.empty()
  let first = @queue.push(empty, 10)
  let second = @queue.push(first, 20)
  assert_eq(@queue.to_array(first), [10])
  assert_eq(@queue.to_array(empty), [])
  assert_eq(@queue.peek(second), Some(10))
  let (value, rest) = @queue.pop(second).unwrap()
  assert_eq(value, 10)
  assert_eq(@queue.peek(rest), Some(20))
  assert_true(@queue.pop(empty) is None)
}

///|
test "quickcheck: queue operation traces agree with an array model" {
  @quickcheck.check(
    (operations : Array[@commands.Command]) => {
      let mut state : @queue.Queue[Int] = @queue.empty()
      let reference : Array[Int] = []
      for operation in operations {
        let before = state
        let snapshot = @queue.to_array(before)
        match operation {
          Push(value) => {
            state = @queue.push(state, value)
            reference.push(value)
          }
          Pop => {
            let expected = if reference.is_empty() {
              None
            } else {
              Some(reference.remove(0))
            }
            match @queue.pop(state) {
              None => if expected is Some(_) { return false }
              Some((value, rest)) => {
                if expected != Some(value) {
                  return false
                }
                state = rest
              }
            }
          }
          Peek => ()
          Clear => {
            state = @queue.empty()
            reference.clear()
          }
        }
        let expected = reference
        if @queue.to_array(state) != expected ||
          @queue.is_empty(state) != reference.is_empty() ||
          @queue.peek(state) != expected.get(0) ||
          @queue.to_array(before) != snapshot {
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
