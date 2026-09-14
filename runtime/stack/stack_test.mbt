///|
test "LIFO and persistent snapshots" {
  let empty : @stack.Stack[Int] = @stack.empty()
  let first = @stack.push(empty, 10)
  let second = @stack.push(first, 20)
  assert_eq(@stack.to_array(first), [10])
  assert_eq(@stack.to_array(empty), [])
  assert_eq(@stack.peek(second), Some(20))
  let (value, rest) = @stack.pop(second).unwrap()
  assert_eq(value, 20)
  assert_eq(@stack.peek(rest), Some(10))
  assert_true(@stack.pop(empty) is None)
}

///|
test "quickcheck: stack operation traces agree with an array model" {
  @quickcheck.check(
    (operations : Array[@commands.Command]) => {
      let mut state : @stack.Stack[Int] = @stack.empty()
      let reference : Array[Int] = []
      for operation in operations {
        let before = state
        let snapshot = @stack.to_array(before)
        match operation {
          Push(value) => {
            state = @stack.push(state, value)
            reference.push(value)
          }
          Pop => {
            let expected = reference.pop()
            match @stack.pop(state) {
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
            state = @stack.empty()
            reference.clear()
          }
        }
        let expected = reference.rev()
        if @stack.to_array(state) != expected ||
          @stack.is_empty(state) != reference.is_empty() ||
          @stack.peek(state) != expected.get(0) ||
          @stack.to_array(before) != snapshot {
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
