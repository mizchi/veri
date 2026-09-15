///|
/// Write one cell; return false without mutation if the index is invalid.
pub fn[T] set(
  array : FixedArray[T],
  index : Int,
  value : T,
) -> Bool where {
  proof_ensure: result => result == (0 <= index && index < array.length()),
  proof_ensure: result => result → same(array[index], value),
} {
  if 0 <= index && index < array.length() {
    array[index] = value
    true
  } else {
    false
  }
}

///|
/// Exchange two cells. Check both indices before writing; equal indices are valid.
/// The local assertions prove the exchanged values. The public contract exposes
/// success/bounds; preservation of other cells is checked by QuickCheck.
pub fn[T] swap(
  array : FixedArray[T],
  left : Int,
  right : Int,
) -> Bool where {
  proof_ensure: result => {
    result ==
    (0 <= left && left < array.length() && 0 <= right && right < array.length())
  },
} {
  if 0 <= left && left < array.length() && 0 <= right && right < array.length() {
    let first = array[left]
    let second = array[right]
    array[left] = second
    array[right] = first
    proof_assert cells_same(array, left, second)
    proof_assert cells_same(array, right, first)
    true
  } else {
    false
  }
}

///|
/// Fill [range.start, range.start + range.count). An invalid range returns false without mutation.
pub fn[T] fill(
  array : FixedArray[T],
  value : T,
  range : Range,
) -> Bool where {
  proof_ensure: result => {
    result == range_in_bounds(array.length(), range.start, range.count)
  },
  proof_ensure: result => {
    result →
    (∀ i : Int,
      range.start <= i && i < range.start + range.count →
      same(array[i], value))
  },
} {
  if valid_range_impl(array.length(), range.start, range.count) {
    for i = 0; i < range.count; i = i + 1 {
      array[range.start + i] = value
    } where {
      proof_invariant: 0 <= i && i <= range.count,
      proof_invariant: filled_prefix(array, range.start, i, value),
    }
    true
  } else {
    false
  }
}

///|
/// Verified copy between distinct arrays. Passing aliases is outside its domain
/// and rejected by the verifier. Use blit when the arrays might alias, or
/// copy_within for a verified operation on one array.
/// Both ranges are checked before writing. Uses constant auxiliary space.
pub fn[T] blit_disjoint(
  source : FixedArray[T],
  target : FixedArray[T],
  source_range : Range,
  target_start : Int,
) -> Bool where {
  proof_ensure: result => {
    result ==
    (
      range_in_bounds(source.length(), source_range.start, source_range.count) &&
      range_in_bounds(target.length(), target_start, source_range.count)
    )
  },
  proof_ensure: result => {
    result →
    (∀ i : Int,
      0 <= i && i < source_range.count →
      same(target[target_start + i], source[source_range.start + i]))
  },
} {
  if valid_range_impl(source.length(), source_range.start, source_range.count) &&
    valid_range_impl(target.length(), target_start, source_range.count) {
    for i = 0; i < source_range.count; i = i + 1 {
      target[target_start + i] = source[source_range.start + i]
    } where {
      proof_invariant: 0 <= i && i <= source_range.count,
      proof_invariant: copied_prefix(
        source,
        source_range.start,
        target,
        target_start,
        i,
      ),
    }
    true
  } else {
    false
  }
}

///|
/// Copy within one array, including overlapping ranges, with memmove semantics.
/// Uses constant auxiliary space; invalid ranges return false without mutation.
/// The contract proves range validation and safe indexing. The pre-state copying
/// and frame properties are specified in arrays/range and checked by QuickCheck.
pub fn[T] copy_within(
  array : FixedArray[T],
  source_range : Range,
  target_start : Int,
) -> Bool where {
  proof_ensure: result => {
    result ==
    (
      range_in_bounds(array.length(), source_range.start, source_range.count) &&
      range_in_bounds(array.length(), target_start, source_range.count)
    )
  },
} {
  if valid_range_impl(array.length(), source_range.start, source_range.count) &&
    valid_range_impl(array.length(), target_start, source_range.count) {
    if source_range.start < target_start {
      for copied = 0; copied < source_range.count; copied = copied + 1 {
        let i = source_range.count - copied - 1
        array[target_start + i] = array[source_range.start + i]
      } where {
        proof_invariant: 0 <= copied && copied <= source_range.count,
      }
    } else if target_start < source_range.start {
      for i = 0; i < source_range.count; i = i + 1 {
        array[target_start + i] = array[source_range.start + i]
      } where {
        proof_invariant: 0 <= i && i <= source_range.count,
      }
    }
    true
  } else {
    false
  }
}
