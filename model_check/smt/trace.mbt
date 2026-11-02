///|
fn changes(
  before : Json?,
  after : Json?,
  path : String,
  output : Array[Json],
) -> Unit {
  if before == after {
    return
  }
  if before is Some(Object(left)) && after is Some(Object(right)) {
    let keys = left.keys().to_array()
    for key in right.keys() {
      if !left.contains(key) {
        keys.push(key)
      }
    }
    keys.sort()
    for key in keys {
      changes(
        left.get(key),
        right.get(key),
        path + "/" + key.replace(old="~", new="~0").replace(old="/", new="~1"),
        output,
      )
    }
  } else {
    output.push({
      "path": Json(path),
      "before": before.unwrap_or(null),
      "after": after.unwrap_or(null),
      "before_present": before is Some(_),
      "after_present": after is Some(_),
    })
  }
}

///|
/// Explain only certificates accepted by the graph evaluator. Paths are JSON pointers.
pub fn describe(
  model : @model_check.Model[Json],
  property : @model_check.Property,
  witness : @model_check.Witness,
  justice~ : Array[Int32] = [],
) -> Json raise {
  guard evaluate(model, property, witness, justice~) else {
    raise InvalidSolverOutput("Cannot explain an invalid witness")
  }
  let steps = []
  for i, action in witness.actions {
    let before = model.states[witness.states[i]]
    let after = model.states[witness.states[i + 1]]
    let diff = []
    changes(Some(before), Some(after), "", diff)
    steps.push({
      "index": Json(i),
      "action": Json(model.actions[action]),
      "from": Json(witness.states[i]),
      "to": Json(witness.states[i + 1]),
      "changes": Json(diff),
    })
  }
  let mut violation_at = -1
  if property is @model_check.Safety(name) {
    let flags = model.predicates.get(name).unwrap()
    for i, state in witness.states {
      if !flags[state] {
        violation_at = i
        break
      }
    }
  }
  let result : Map[String, Json] = {
    "property": property.to_json(),
    "initial": model.states[model.initial],
    "steps": Json(steps),
    "justice": Json(justice.map(a => model.actions[a])),
  }
  if violation_at >= 0 {
    result.set("violation_at", Json(violation_at))
  }
  if witness.loop_start is Some(index) {
    result.set("loop_start", Json(index))
  }
  Json(result)
}
