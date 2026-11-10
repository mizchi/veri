///|
/// The textbook midpoint `(low + high) / 2` over `(_ BitVec 32)`.
pub fn midpoint(
  ctx : @smtlib.Context,
  low : @smtlib.Term,
  high : @smtlib.Term,
) -> @smtlib.Term raise @smtlib.SmtError {
  ctx.bv_udiv(ctx.bv_add(low, high), ctx.literal(2U))
}

///|
/// `low + (high - low) / 2`, which cannot wrap when `low <= high`.
pub fn safe_midpoint(
  ctx : @smtlib.Context,
  low : @smtlib.Term,
  high : @smtlib.Term,
) -> @smtlib.Term raise @smtlib.SmtError {
  ctx.bv_add(low, ctx.bv_udiv(ctx.bv_sub(high, low), ctx.literal(2U)))
}

///|
/// `low <= high` implies `low <= middle <= high`, all unsigned.
pub fn in_range(
  ctx : @smtlib.Context,
  low : @smtlib.Term,
  middle : @smtlib.Term,
  high : @smtlib.Term,
) -> @smtlib.Term raise @smtlib.SmtError {
  ctx.implies(
    ctx.bv_ule(low, high),
    ctx.and_(ctx.bv_ule(low, middle), ctx.bv_ule(middle, high)),
  )
}
