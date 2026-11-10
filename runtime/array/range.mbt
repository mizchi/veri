///|
/// A half-open range [start, start + count). Creating a Range does not validate it;
/// operations check it without overflowing and reject invalid ranges atomically.
#derive(Debug, Eq)
#valtype
pub(all) struct Range {
  start : Int32
  count : Int32
}

///|
pub extend Range with @debug.Debug::{to_repr}

///|
pub extend Range with Eq::{not_equal, equal}

///|
/// Validate a range without overflowing, including extreme invalid endpoints.
pub fn valid_range(
  length : Int32,
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
  length : Int32,
  start : Int32,
  count : Int32,
) -> Bool where {
  proof_ensure: result => result == range_in_bounds(length, start, count),
} {
  0 <= start && start <= length && 0 <= count && count <= length - start
}
