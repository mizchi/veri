///|
/// The core Set itself: no wrapper, extra allocation, or replacement algorithm.
pub using @core {type Set}

///|
/// Exact contents check against distinct elements, in any order.
/// Duplicate elements are rejected. This opt-in checker is runtime-tested, not proved.
pub fn[K : Hash + Eq] matches_elements(
  value : Set[K],
  elements : ArrayView[K],
) -> Bool {
  if value.length() != elements.length() {
    return false
  }
  let seen : Set[K] = Set([])
  for key in elements {
    if !seen.add_and_check(key) || !value.contains(key) {
      return false
    }
  }
  true
}
