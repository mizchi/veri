///|
/// Exact nonnegative edge-relaxation check without computing an overflowing sum.
/// This function's body is proved under both integer models and is used by the
/// complete certificate checker; soundness.mbtp connects the local checks to paths.
pub fn relaxation(
  cost : Int,
  next : Int,
  weight : Int,
) -> Bool where {
  proof_ensure: result => {
    result ==
    (
      cost >= 0 &&
      next >= 0 &&
      weight >= 0 &&
      @integer.le(
        @integer.from_int(next),
        @integer.add(@integer.from_int(cost), @integer.from_int(weight)),
      )
    )
  },
} {
  cost >= 0 &&
  next >= 0 &&
  weight >= 0 &&
  (next <= cost || next - cost <= weight)
}
