///|
/// Define each event and predicate once. Callbacks must be deterministic and
/// states immutable; snapshots are for presentation, never state identity.
pub(all) struct Spec[S, E, Snapshot] {
  initial : S
  actions : Array[(String, E)]
  step : (S, E) -> S?
  predicates : Array[(String, (S) -> Bool)]
  snapshot : (S) -> Snapshot
  justice : Array[String]
}

///|
pub(all) suberror BuilderError {
  InvalidDefinition(String)
} derive(Debug)

///|
fn[S, E, J] Spec::validate(
  self : Spec[S, E, J],
) -> Array[Int] raise BuilderError {
  let names : Map[String, Int] = Map([])
  for i, pair in self.actions {
    let (name, _) = pair
    guard !name.is_empty() && !names.contains(name) else {
      raise InvalidDefinition("Duplicate or empty action")
    }
    names.set(name, i)
  }
  guard !names.is_empty() else { raise InvalidDefinition("No actions") }
  let predicates : Map[String, Bool] = Map([])
  for pair in self.predicates {
    let (name, _) = pair
    guard !name.is_empty() && !predicates.contains(name) else {
      raise InvalidDefinition("Duplicate or empty predicate")
    }
    predicates.set(name, true)
  }
  let justice = []
  for name in self.justice {
    let id = match names.get(name) {
      Some(id) => id
      None => raise InvalidDefinition("Unknown fairness action: " + name)
    }
    guard !justice.contains(id) else {
      raise InvalidDefinition("Duplicate fairness action")
    }
    justice.push(id)
  }
  justice
}

///|
fn[S, E, J] finish_client(
  spec : Spec[S, E, J],
  states : Array[S],
  transitions : Array[Array[Int]],
  initial : Int,
  justice : Array[Int],
  exploration : Scope?,
) -> Client[S, E, J] {
  let definitions = spec.predicates.copy()
  let predicates = Map([])
  for pair in definitions {
    let (name, holds) = pair
    predicates.set(name, states.map(holds))
  }
  {
    initial: spec.initial,
    states,
    events: spec.actions.map(pair => pair.1),
    step: spec.step,
    holds: (state, name) => {
      for pair in definitions {
        if pair.0 == name {
          return Some((pair.1)(state))
        }
      }
      None
    },
    model: {
      initial,
      actions: spec.actions.map(pair => pair.0),
      states: states.map(spec.snapshot),
      transitions,
      predicates,
      justice,
      exploration,
    },
  }
}

///|
pub fn[S : Eq, E, J] build_client(
  spec : Spec[S, E, J],
  max_depth? : Int = 64,
  max_states? : Int = 4096,
  max_transitions? : Int = 4000000,
  state_hash? : (S) -> Int,
) -> Client[S, E, J] raise {
  let justice = spec.validate()
  let explored = explore(
    spec.initial,
    spec.actions.map(pair => pair.1),
    spec.step,
    max_depth~,
    max_states~,
    max_transitions~,
    state_hash?,
  )
  finish_client(
    spec,
    explored.states,
    explored.transitions,
    0,
    justice,
    Some({
      complete: explored.complete,
      max_depth: explored.max_depth,
      depths: explored.depths,
      frontier: explored.frontier,
    }),
  )
}

///|
/// Keep explicit identifiers (including unreachable states), while requiring a
/// duplicate-free domain closed under every event. No cutoff is hidden as None.
pub fn[S : Eq, E, J] client_from_states(
  spec : Spec[S, E, J],
  domain : Array[S],
) -> Client[S, E, J] raise {
  let justice = spec.validate()
  let states = domain.copy()
  for i, state in states {
    for j = 0; j < i; j = j + 1 {
      guard state != states[j] else {
        raise InvalidDefinition("Duplicate state")
      }
    }
  }
  let initial = match states.search_by(s => s == spec.initial) {
    Some(id) => id
    None => raise InvalidDefinition("Missing initial state")
  }
  let transitions = []
  for state in states {
    let row = []
    for pair in spec.actions {
      let target = match (spec.step)(state, pair.1) {
        None => -1
        Some(next) =>
          match states.search_by(s => s == next) {
            Some(id) => id
            None =>
              raise InvalidDefinition("Explicit state domain is not closed")
          }
      }
      row.push(target)
    }
    transitions.push(row)
  }
  finish_client(spec, states, transitions, initial, justice, None)
}

///|
pub fn[S, E, J] Spec::holds(
  self : Spec[S, E, J],
  state : S,
  name : String,
) -> Bool? {
  for pair in self.predicates {
    if pair.0 == name {
      return Some((pair.1)(state))
    }
  }
  None
}
