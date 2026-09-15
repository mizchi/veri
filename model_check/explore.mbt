///|
pub(all) suberror ExplorationError {
  InvalidDepth(Int)
  InvalidStateLimit(Int)
  InvalidEventCount(Int)
  StateLimitExceeded(Int)
} derive(Debug, Eq)

///|
pub(all) struct Exploration[S] {
  states : Array[S]
  transitions : Array[Array[Int]]
  depths : Array[Int]
  frontier : Array[Int]
  max_depth : Int
  complete : Bool
}

///|
/// Breadth-first exploration with explicit depth and resource limits.
/// A frontier row may omit enabled successors outside the depth bound. Such a
/// graph preserves safety/reachability prefixes up to max_depth, not liveness.
/// Exhausting max_states raises an error instead of returning a partial success.
/// Supply immutable states, a deterministic step, and all action choices.
/// Equality must compare the entire state represented by the model.
pub fn[S : Eq, E] explore(
  initial : S,
  events : Array[E],
  step : (S, E) -> S?,
  max_depth~ : Int,
  max_states? : Int = 4096,
) -> Exploration[S] raise ExplorationError {
  guard max_depth >= 0 && max_depth <= 64 else { raise InvalidDepth(max_depth) }
  guard max_states > 0 && max_states <= 4096 else {
    raise InvalidStateLimit(max_states)
  }
  guard events.length() > 0 && events.length() <= 64 else {
    raise InvalidEventCount(events.length())
  }
  let states = [initial]
  let depths = [0]
  let transitions = []
  let frontier = []
  let mut cursor = 0
  while cursor < states.length() {
    let row = []
    let mut omitted = false
    for event in events {
      let target = match step(states[cursor], event) {
        None => -1
        Some(next) =>
          match states.search_by(s => s == next) {
            Some(index) => index
            None =>
              if depths[cursor] == max_depth {
                omitted = true
                -1
              } else {
                let index = states.length()
                guard index < max_states else {
                  raise StateLimitExceeded(max_states)
                }
                states.push(next)
                depths.push(depths[cursor] + 1)
                index
              }
          }
      }
      row.push(target)
    }
    transitions.push(row)
    if omitted {
      frontier.push(cursor)
    }
    cursor += 1
  }
  {
    states,
    transitions,
    depths,
    frontier,
    max_depth,
    complete: frontier.is_empty(),
  }
}
