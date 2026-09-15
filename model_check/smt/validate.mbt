///|
pub(all) suberror ModelError {
  InvalidModel(String)
  InvalidQuery(String)
  InvalidSolverOutput(String)
} derive(Debug)

///|
pub fn validate(model : @model_check.Model[Json]) -> Unit raise ModelError {
  let n = model.transitions.length()
  let m = model.actions.length()
  guard n > 0 && m > 0 && n <= 4000000 / m else {
    raise InvalidModel("State/action limit")
  }
  guard model.initial >= 0 && model.initial < n && model.states.length() == n else {
    raise InvalidModel("State domain")
  }
  let names : Map[String, Bool] = Map([])
  for name in model.actions {
    guard !names.contains(name) else { raise InvalidModel("Duplicate action") }
    names.set(name, true)
  }
  for row in model.transitions {
    guard row.length() == m else { raise InvalidModel("Transition row length") }
    for next in row {
      guard next >= -1 && next < n else {
        raise InvalidModel("Transition target")
      }
    }
  }
  for _, flags in model.predicates {
    guard flags.length() == n else { raise InvalidModel("Predicate length") }
  }
  validate_justice(model, model.justice)
  if model.exploration is Some(scope) {
    guard scope.max_depth >= 0 &&
      scope.max_depth <= 1000000 &&
      scope.depths.length() == n else {
      raise InvalidModel("Exploration depth")
    }
    guard scope.depths[model.initial] == 0 else {
      raise InvalidModel("Initial depth")
    }
    for depth in scope.depths {
      guard depth >= 0 && depth <= scope.max_depth else {
        raise InvalidModel("State depth")
      }
    }
    let seen = Array::make(n, false)
    for id in scope.frontier {
      guard id >= 0 &&
        id < n &&
        !seen[id] &&
        scope.depths[id] == scope.max_depth else {
        raise InvalidModel("Exploration frontier")
      }
      seen[id] = true
    }
    guard scope.complete == scope.frontier.is_empty() else {
      raise InvalidModel("Exploration completeness")
    }
  }
}

///|
fn validate_justice(
  model : @model_check.Model[Json],
  justice : Array[Int],
) -> Unit raise ModelError {
  let seen = Array::make(model.actions.length(), false)
  for action in justice {
    guard action >= 0 && action < seen.length() && !seen[action] else {
      raise InvalidQuery("Invalid justice action")
    }
    seen[action] = true
  }
}

///|
pub fn validate_query(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  depth : Int,
  justice? : Array[Int] = [],
) -> Unit raise ModelError {
  validate(model)
  guard depth >= 0 && depth <= 1000000 else {
    raise InvalidQuery("Bound must be in 0..1000000")
  }
  let names = match property {
    Safety(name) | Reachability(name) | Deadlock(name) => [name]
    Response(trigger, goal) => {
      guard depth > 0 else {
        raise InvalidQuery("Response requires a positive bound")
      }
      [trigger, goal]
    }
  }
  for name in names {
    guard model.predicates.contains(name) else {
      raise InvalidQuery("Unknown predicate: " + name)
    }
  }
  validate_justice(model, justice)
  if model.exploration is Some(scope) && !scope.complete {
    guard depth <= scope.max_depth && !(property is Response(_, _)) else {
      raise InvalidQuery("Incomplete exploration")
    }
  }
}
