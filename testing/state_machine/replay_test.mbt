///|
fn model() -> @state_machine.Model[
  Array[Int],
  @commands.Command,
  Int?,
  Array[Int],
] {
  {
    initial: () => [],
    step: (before, command) => {
      let values = before.copy()
      let result = match command {
        Push(value) => {
          values.push(value)
          None
        }
        Pop => if values.is_empty() { None } else { Some(values.remove(0)) }
        Peek => values.get(0)
        Clear => {
          values.clear()
          None
        }
      }
      Some((values, result))
    },
    observe: values => values.copy(),
  }
}

///|
fn system(
  broken : Bool,
  closed : Array[Int],
) -> @state_machine.System[
  @queue.Queue[Int],
  @commands.Command,
  Int?,
  Array[Int],
] {
  {
    create: () => @queue.Queue([]),
    step: (queue, command) => {
      let result = match command {
        Push(value) => {
          queue.push(if broken && value >= 3 { value + 1 } else { value })
          None
        }
        Pop => queue.pop()
        Peek => queue.peek()
        Clear => {
          queue.clear()
          None
        }
      }
      (queue, result)
    },
    observe: queue => queue.iter().to_array(),
    close: _ => closed.push(1),
  }
}

///|
test "state machine compares core queue with fresh state and shrinking" {
  let closed = []
  @state_machine.check(
    model(),
    system(false, closed),
    count=1000,
    seed=20260916,
  )
  assert_true(closed.length() >= 1000)
  let report = @quickcheck.report(
    (commands : Array[@commands.Command]) => {
      @state_machine.replay(model(), system(true, []), commands).verdict ==
      Matched
    },
    count=1000,
    seed=20260916,
    max_shrinks=1000,
  )
  let text = @debug.to_string(report)
  assert_true(text.contains("counterexample=[Push(3)]"))
}

///|
test "disabled commands are not implementation failures and cleanup always runs" {
  let closed = []
  let disabled = { ..model(), step: (_, _) => None, }
  let report = @state_machine.replay(disabled, system(false, closed), [Push(1)])
  assert_eq(report.verdict, InvalidCommand)
  assert_eq(closed.length(), 1)
  let broken = @state_machine.replay(model(), system(true, closed), [Push(3)])
  assert_eq(broken.verdict, Mismatch)
  assert_eq(broken.index, 0)
  assert_eq(broken.expected_state, Some([3]))
  assert_eq(broken.actual_state, Some([4]))
  assert_eq(closed.length(), 2)
}

///|
suberror InjectedFailure {
  Boom
}

///|
test "unexpected implementation errors propagate after cleanup" {
  let closed = []
  let throwing = { ..system(false, closed), step: (_, _) => raise Boom, }
  assert_true(
    try {
      ignore(@state_machine.replay(model(), throwing, [Push(1)]))
      false
    } catch {
      Boom => true
      _ => false
    },
  )
  assert_eq(closed.length(), 1)
}
