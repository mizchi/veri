///|
pub(all) struct ExhaustiveResult {
  witness : @model_check.Witness?
  visited : Int
  // Largest BFS depth among visited states; a response lasso can be longer.
  max_depth : Int
}

///|
/// Exhaust the reachable closure of a declared-complete finite graph. This is
/// model checking, not a theorem about the source program or an infinite system.
/// Response checks use SCCs and optional weak fairness; other properties reject
/// nonempty justice. Witnesses for response need not be shortest.
pub fn exhaustive(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  justice? : Array[Int] = [],
) -> ExhaustiveResult raise {
  validate_query(
    model,
    property,
    if property is @model_check.Response(_, _) {
      1
    } else {
      0
    },
    justice~,
  )
  guard !(model.exploration is Some(scope) && !scope.complete) else {
    raise InvalidQuery("Complete exploration required")
  }
  if property is @model_check.Response(trigger, goal) {
    return exhaustive_response(model, trigger, goal, justice)
  }
  guard justice.is_empty() else {
    raise InvalidQuery("Complete fairness requires a response property")
  }
  let n = model.states.length()
  let parent = Array::make(n, -1)
  let incoming = Array::make(n, -1)
  let depth = Array::make(n, 0)
  let queue = [model.initial]
  parent[model.initial] = model.initial
  let mut cursor = 0
  let mut max_depth = 0
  while cursor < queue.length() {
    let state = queue[cursor]
    max_depth = depth[state]
    let found = match property {
      Safety(name) => !model.predicates.get(name).unwrap()[state]
      Reachability(name) => model.predicates.get(name).unwrap()[state]
      Deadlock(name) =>
        !model.predicates.get(name).unwrap()[state] &&
        model.transitions[state].all(next => next < 0)
      Response(_, _) => false
    }
    if found {
      let states = [state]
      let actions = []
      let mut id = state
      while id != model.initial {
        actions.push(incoming[id])
        id = parent[id]
        states.push(id)
      }
      states.rev_in_place()
      actions.rev_in_place()
      return {
        witness: Some({ states, actions, loop_start: None, }),
        visited: cursor + 1,
        max_depth,
      }
    }
    for action, next in model.transitions[state] {
      if next >= 0 && parent[next] < 0 {
        parent[next] = state
        incoming[next] = action
        depth[next] = depth[state] + 1
        queue.push(next)
      }
    }
    cursor += 1
  }
  { witness: None, visited: cursor, max_depth, }
}
