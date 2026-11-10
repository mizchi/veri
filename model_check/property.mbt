///|
#derive(@json.FromJson)
struct WireProperty {
  kind : String
  predicate : String?
  trigger : String?
  goal : String?
  terminal : String?
}

///|
pub extend WireProperty with @json.FromJson::{from_json}

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
pub extend Property with @json.FromJson::{from_json}

///|
pub impl ToJson for Property with fn to_json(self) {
  match self {
    Deadlock(terminal) => { "kind": "deadlock", "terminal": Json(terminal) }
    Safety(name) => { "kind": "safety", "predicate": Json(name) }
    Reachability(name) => { "kind": "reachability", "predicate": Json(name) }
    Response(trigger, goal) =>
      { "kind": "response", "trigger": Json(trigger), "goal": Json(goal) }
  }
}

///|
pub extend Property with ToJson::{to_json}
