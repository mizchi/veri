///|
struct WireProperty {
  kind : String
  predicate : String?
  trigger : String?
  goal : String?
} derive(@json.FromJson)

///|
pub impl @json.FromJson for Property with fn from_json(json, path) {
  let wire : WireProperty = @json.from_json(json, path~)
  match (wire.kind, wire.predicate, wire.trigger, wire.goal) {
    ("safety", Some(name), None, None) => Safety(name)
    ("reachability", Some(name), None, None) => Reachability(name)
    ("response", None, Some(trigger), Some(goal)) => Response(trigger, goal)
    _ => raise @json.JsonDecodeError((path, "Invalid model property"))
  }
}

///|
pub impl ToJson for Property with fn to_json(self) {
  match self {
    Safety(name) => { "kind": "safety", "predicate": name.to_json() }
    Reachability(name) =>
      { "kind": "reachability", "predicate": name.to_json() }
    Response(trigger, goal) =>
      {
        "kind": "response",
        "trigger": trigger.to_json(),
        "goal": goal.to_json(),
      }
  }
}
