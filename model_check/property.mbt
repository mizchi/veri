///|
struct WireProperty {
  kind : String
  predicate : String?
  trigger : String?
  goal : String?
  terminal : String?
} derive(@json.FromJson)

///|
pub impl @json.FromJson for Property with fn from_json(json, path) {
  let wire : WireProperty = @json.from_json(json, path~)
  match (wire.kind, wire.predicate, wire.trigger, wire.goal, wire.terminal) {
    ("safety", Some(name), None, None, None) => Safety(name)
    ("reachability", Some(name), None, None, None) => Reachability(name)
    ("response", None, Some(trigger), Some(goal), None) =>
      Response(trigger, goal)
    ("deadlock", None, None, None, Some(terminal)) => Deadlock(terminal)
    _ => raise @json.JsonDecodeError((path, "Invalid model property"))
  }
}

///|
pub impl ToJson for Property with fn to_json(self) {
  match self {
    Deadlock(terminal) => { "kind": "deadlock", "terminal": terminal.to_json() }
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
