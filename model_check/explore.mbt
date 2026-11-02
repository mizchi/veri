///|
pub(all) suberror ExplorationError {
  InvalidDepth(Int32)
  InvalidStateLimit(Int32)
  InvalidEventCount(Int32)
  StateLimitExceeded(Int32)
  TransitionLimitExceeded(Int32)
} derive(Debug, Eq)

///|
pub extend ExplorationError with @debug.Debug::{to_repr}

///|
pub extend ExplorationError with Eq::{not_equal, equal}

///|
pub(all) struct Exploration[S] {
  states : Array[S]
  transitions : Array[Array[Int32]]
  depths : Array[Int32]
  frontier : Array[Int32]
  max_depth : Int32
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
  max_depth~ : Int32,
  max_states~ : Int32 = 4096,
  max_transitions~ : Int32 = 4000000,
  state_hash? : (S) -> Int32,
) -> Exploration[S] raise ExplorationError {
  guard max_depth >= 0 && max_depth <= 1000000 else {
    raise InvalidDepth(max_depth)
  }
  guard max_states > 0 else { raise InvalidStateLimit(max_states) }
  guard events.length() > 0 else { raise InvalidEventCount(events.length()) }
  guard max_transitions > 0 else {
    raise TransitionLimitExceeded(max_transitions)
  }
  let buckets : Map[Int32, Array[Int32]] = Map([])
  if state_hash is Some(hash) {
    buckets.set(hash(initial), [0])
  }
  let states = [initial]
  let depths = [0]
  let transitions = []
  let frontier = []
  let mut cursor = 0
  while cursor < states.length() {
    guard cursor < max_transitions / events.length() else {
      raise TransitionLimitExceeded(max_transitions)
    }
    let row = []
    let mut omitted = false
    for event in events {
      let target = match step(states[cursor], event) {
        None => -1
        Some(next) =>
          match
            (match state_hash {
              None => states.search_by(s => s == next)
              Some(hash) =>
                buckets
                .get(hash(next))
                .bind(ids => {
                  ids.search_by(id => states[id] == next).map(i => ids[i])
                })
            }) {
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
                if state_hash is Some(hash) {
                  let key = hash(next)
                  match buckets.get(key) {
                    Some(ids) => ids.push(index)
                    None => buckets.set(key, [index])
                  }
                }
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
