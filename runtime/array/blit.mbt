///|
/// Copy [source_range.start, source_range.start + source_range.count), allowing overlapping arrays.
/// Invalid ranges return false before any mutation. Uses constant extra space.
/// This alias-aware dispatcher is runtime-tested. Verified callers can use
/// blit_disjoint for distinct arrays or copy_within for one array.
pub fn[T] blit(
  source : FixedArray[T],
  target : FixedArray[T],
  source_range : Range,
  target_start : Int,
) -> Bool {
  if physical_equal(source, target) {
    copy_within(source, source_range, target_start)
  } else {
    blit_disjoint(source, target, source_range, target_start)
  }
}
