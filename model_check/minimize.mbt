///|
pub(all) struct Minimized[T] {
  value : T
  attempts : Int
  exhausted : Bool
}

///|
pub(all) suberror MinimizeError {
  InvalidMinimization
} derive(Debug)

///|
/// Greedy shrinking under a strictly decreasing nonnegative cost, with a hard
/// candidate budget. preserves must replay the failure using fresh state.
/// Supply core Shrink::shrink(input).iter() as candidates when appropriate.
pub fn[T] minimize(
  input : T,
  preserves : (T) -> Bool,
  candidates~ : (T) -> Iter[T],
  cost~ : (T) -> Int,
  max_attempts? : Int = 1000,
) -> Minimized[T] raise MinimizeError {
  guard max_attempts > 0 && cost(input) >= 0 && preserves(input) else {
    raise InvalidMinimization
  }
  let mut value = input
  let mut weight = cost(input)
  let mut attempts = 0
  while attempts < max_attempts {
    let mut improved = false
    for candidate in candidates(value) {
      if attempts == max_attempts {
        break
      }
      attempts += 1
      let next_weight = cost(candidate)
      if next_weight >= 0 && next_weight < weight && preserves(candidate) {
        value = candidate
        weight = next_weight
        improved = true
        break
      }
    }
    if !improved {
      break
    }
  }
  { value, attempts, exhausted: attempts == max_attempts, }
}
