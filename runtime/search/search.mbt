///|
fn lower_search(
  xs : FixedArray[Int],
  value : Int,
  left : Int,
  right : Int,
) -> Int where {
  proof_require: ordered(xs),
  proof_require: 0 <= left && left <= right && right <= xs.length(),
  proof_require: lower_left(xs, value, left),
  proof_require: lower_right(xs, value, right),
  proof_ensure: index => lower_partition(xs, value, index),
  proof_decrease: width(left, right),
} {
  if left < right {
    let middle = left + (right - left) / 2
    if xs[middle] < value {
      lower_search(xs, value, middle + 1, right)
    } else {
      lower_search(xs, value, left, middle)
    }
  } else {
    left
  }
}

///|
/// First index whose value is >= value. Requires ascending input.
/// O(log n), no copying or sortedness scan. Check is_sorted for untrusted input.
pub fn lower_bound(
  xs : FixedArray[Int],
  value : Int,
) -> Int where {
  proof_require: ordered(xs),
  proof_ensure: index => lower_partition(xs, value, index),
} {
  lower_search(xs, value, 0, xs.length())
}

///|
fn upper_search(
  xs : FixedArray[Int],
  value : Int,
  left : Int,
  right : Int,
) -> Int where {
  proof_require: ordered(xs),
  proof_require: 0 <= left && left <= right && right <= xs.length(),
  proof_require: upper_left(xs, value, left),
  proof_require: upper_right(xs, value, right),
  proof_ensure: index => upper_partition(xs, value, index),
  proof_decrease: width(left, right),
} {
  if left < right {
    let middle = left + (right - left) / 2
    if xs[middle] <= value {
      upper_search(xs, value, middle + 1, right)
    } else {
      upper_search(xs, value, left, middle)
    }
  } else {
    left
  }
}

///|
/// First index whose value is > value. Requires ascending input.
/// O(log n), no copying or sortedness scan. Check is_sorted for untrusted input.
pub fn upper_bound(
  xs : FixedArray[Int],
  value : Int,
) -> Int where {
  proof_require: ordered(xs),
  proof_ensure: index => upper_partition(xs, value, index),
} {
  upper_search(xs, value, 0, xs.length())
}

///|
/// O(n) check of the exact precondition required by the verified bounds searches.
pub fn is_sorted(
  xs : FixedArray[Int],
) -> Bool where {
  proof_ensure: result => result == ordered(xs),
} {
  let mut result = true
  for i = 0; i < xs.length(); i = i + 1 {
    if i > 0 && xs[i - 1] > xs[i] {
      result = false
    }
  } where {
    proof_invariant: 0 <= i && i <= xs.length(),
    proof_invariant: result == ordered_prefix(xs, i),
  }
  result
}

///|
/// Check ascending order and preservation of every multiplicity. Expected O(n)
/// time and O(distinct values) space. Keep a pre-sort copy when sorting in place.
/// This checker is differential-tested; core Map operations are not proof-callable.
pub fn check_sort(before : ArrayView[Int], after : ArrayView[Int]) -> Bool {
  if before.length() != after.length() {
    return false
  }
  let counts : Map[Int, Int] = Map([])
  for value in before {
    counts.set(value, counts.get(value).unwrap_or(0) + 1)
  }
  for i = 0; i < after.length(); i = i + 1 {
    if i > 0 && after[i - 1] > after[i] {
      return false
    }
    let value = after[i]
    match counts.get(value) {
      None => return false
      Some(1) => counts.remove(value)
      Some(count) => counts.set(value, count - 1)
    }
  }
  counts.is_empty()
}
