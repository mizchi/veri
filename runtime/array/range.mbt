///|
/// A half-open range [start, start + count). Creating a Range does not validate it;
/// operations check it without overflowing and reject invalid ranges atomically.
#valtype
pub(all) struct Range {
  start : Int
  count : Int
} derive(Debug, Eq)

///|
/// Validate a range without overflowing, including extreme invalid endpoints.
pub fn valid_range(
  length : Int,
  range : Range,
) -> Bool where {
  proof_ensure: result => {
    result == range_in_bounds(length, range.start, range.count)
  },
} {
  valid_range_impl(length, range.start, range.count)
}

///|
fn valid_range_impl(
  length : Int,
  start : Int,
  count : Int,
) -> Bool where {
  proof_ensure: result => result == range_in_bounds(length, start, count),
} {
  0 <= start && start <= length && 0 <= count && count <= length - start
}
