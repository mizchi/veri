///|
/// The core Map itself: no wrapper, extra allocation, or replacement algorithm.
pub using @core {type Map}

///|
/// Exact contents check against a unique-key snapshot, in any order.
/// Duplicate keys are rejected. This opt-in checker is runtime-tested, not proved.
pub fn[K : Hash + Eq, V : Eq] matches_entries(
  value : Map[K, V],
  entries : ArrayView[(K, V)],
) -> Bool {
  if value.length() != entries.length() {
    return false
  }
  let seen : Set[K] = Set([])
  for (key, expected) in entries {
    if !seen.add_and_check(key) || value.get(key) != Some(expected) {
      return false
    }
  }
  true
}
