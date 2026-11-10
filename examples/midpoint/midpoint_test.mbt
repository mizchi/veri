///|
test "a term evaluates like the runtime code it describes" {
  let ctx = @smtlib.Context::new()
  let low : @smtlib.Typed[UInt32] = ctx.typed("low")
  let high : @smtlib.Typed[UInt32] = ctx.typed("high")
  let middle = @midpoint.midpoint(ctx, low.term, high.term)
  let inputs = @smtlib.Model::new()
  inputs.bind(low, 0xf000_0000U)
  inputs.bind(high, 0xffff_ffffU)
  // `UInt` is `(_ BitVec 32)`: the term wraps exactly like the native code.
  let value : UInt32 = ctx.eval_as(middle, inputs)
  assert_eq(value, (0xf000_0000U + 0xffff_ffffU) / 2U)
  assert_eq(value, 0x77ff_ffffU)
  let claim = @midpoint.in_range(ctx, low.term, middle, high.term)
  assert_eq((ctx.eval_as(claim, inputs) : Bool), false)
  let safe = @midpoint.safe_midpoint(ctx, low.term, high.term)
  let repaired = @midpoint.in_range(ctx, low.term, safe, high.term)
  assert_eq((ctx.eval_as(repaired, inputs) : Bool), true)
}

///|
test "the same term becomes a solver query and its answer runtime values" {
  let ctx = @smtlib.Context::new()
  let low : @smtlib.Typed[UInt32] = ctx.typed("low")
  let high : @smtlib.Typed[UInt32] = ctx.typed("high")
  let middle = @midpoint.midpoint(ctx, low.term, high.term)
  let script = @smtlib.Script::new(ctx, logic="QF_BV")
  // Ask for inputs that violate the claim. `low + high` occurs once in the
  // term, however often the claim uses the midpoint.
  script.assert_term(
    ctx.not_(@midpoint.in_range(ctx, low.term, middle, high.term)),
  )
  script.check_sat()
  script.get_value([low.term, high.term])
  inspect(
    script.to_string(),
    content=(
      #|(set-logic QF_BV)
      #|(declare-const low (_ BitVec 32))
      #|(declare-const high (_ BitVec 32))
      #|(assert (let (($t4 (bvudiv (bvadd low high) #x00000002))) (not (=> (bvule low high) (and (bvule low $t4) (bvule $t4 high))))))
      #|(check-sat)
      #|(get-value (low high))
      #|
    ),
  )
  // A solver's answer decodes back into the runtime type of each constant.
  let answer = "((low #xf0000000)\n (high #xffffffff))"
  let values = ctx.parse_values(answer, [low.term, high.term])
  let counterexample = @smtlib.Model::new()
  counterexample.set(low.name, values[0])
  counterexample.set(high.name, values[1])
  assert_eq(counterexample.read(low), Some(0xf000_0000U))
  assert_eq(counterexample.read(high), Some(0xffff_ffffU))
  // The interpreter confirms the counterexample without trusting the solver.
  let claim = @midpoint.in_range(ctx, low.term, middle, high.term)
  assert_eq(ctx.eval(claim, counterexample), Boolean(false))
}
