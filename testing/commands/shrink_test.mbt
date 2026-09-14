///|
test "command shrinking preserves the operation and reduces its value" {
  let candidates = @shrink.Shrink::shrink(@commands.Push(100)).to_array()
  assert_true(candidates.length() > 0)
  assert_true(
    candidates.all(command => {
      command is Push(value) && 0 <= value && value < 100
    }),
  )
  assert_true(candidates.contains(@commands.Push(0)))
  let commands : Array[@commands.Command] = [Pop, Peek, Clear]
  for command in commands {
    assert_eq(@shrink.Shrink::shrink(command).count(), 0)
  }
}

///|
test "quickcheck: shrinking removes commands and minimizes a counterexample" {
  let report = @quickcheck.report(
    (commands : Array[@commands.Command]) => {
      // Intentionally false: QuickCheck must find and shrink a Push >= 3.
      commands.all(command => {
        match command {
          Push(value) => value < 3
          _ => true
        }
      })
    },
    count=1000,
    max_size=64,
    max_shrinks=1000,
    seed=20260914,
  )
  let rendered = @debug.to_string(report)
  assert_true(rendered.has_prefix("Falsified("))
  assert_true(rendered.contains("counterexample=[Push(3)]"))
}
