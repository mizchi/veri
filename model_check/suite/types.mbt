///|
/// Expected semantic result; a solver failure is never an expected success.
pub(all) enum Outcome {
  Counterexample
  Witness
  BoundedSafe
  BoundedUnreachable
  CompleteSafe
  CompleteUnreachable
} derive(Eq, Debug)

///|
pub fn Outcome::code(self : Outcome) -> String {
  match self {
    Counterexample => "counterexample"
    Witness => "witness"
    BoundedSafe => "no-counterexample-up-to-bound"
    CompleteSafe => "safe-for-complete-model"
    CompleteUnreachable => "unreachable-in-complete-model"
    BoundedUnreachable => "unreachable-up-to-bound"
  }
}

///|
pub impl ToJson for Outcome with fn to_json(self) {
  self.code().to_json()
}

///|
pub impl @json.FromJson for Outcome with fn from_json(json, path) {
  let code : String = @json.from_json(json, path~)
  match code {
    "counterexample" => Counterexample
    "witness" => Witness
    "no-counterexample-up-to-bound" => BoundedSafe
    "safe-for-complete-model" => CompleteSafe
    "unreachable-in-complete-model" => CompleteUnreachable
    "unreachable-up-to-bound" => BoundedUnreachable
    _ => raise @json.JsonDecodeError((path, "Unknown expected outcome"))
  }
}

///|
pub(all) struct Case {
  name : String
  driver : String
  module_dir : String?
  target : String?
  config : Json?
  property : @model_check.Property
  bound : Int?
  complete : Bool?
  fair : Bool?
  require_trigger : Bool?
  limits : @model_check.Limits?
  justice : Array[Int]?
  expect : Outcome
} derive(@json.FromJson)

///|
pub(all) struct Suite {
  version : Int
  cases : Array[Case]
}

///|
struct WireSuite {
  version : Int
  cases : Array[Case]
} derive(@json.FromJson)

///|
pub impl @json.FromJson for Suite with fn from_json(json, path) {
  let wire : WireSuite = @json.from_json(json, path~)
  guard json is Object(object) else {
    raise @json.JsonDecodeError((path, "Expected suite object"))
  }
  for key in object.keys() {
    guard key == "version" || key == "cases" else {
      raise @json.JsonDecodeError((path, "Unknown suite field: " + key))
    }
  }
  let allowed = [
    "name", "driver", "module_dir", "target", "config", "property", "bound", "complete",
    "fair", "require_trigger", "limits", "justice", "expect",
  ]
  guard object.get("cases") is Some(Array(entries)) else {
    raise @json.JsonDecodeError((path, "Expected case array"))
  }
  for entry in entries {
    guard entry is Object(fields) else {
      raise @json.JsonDecodeError((path, "Expected case object"))
    }
    for key in fields.keys() {
      guard allowed.contains(key) else {
        raise @json.JsonDecodeError((path, "Unknown case field: " + key))
      }
    }
    if fields.get("limits") is Some(Object(limits)) {
      for key in limits.keys() {
        guard ["timeout_ms", "memory_mb", "max_query_bytes", "max_output_bytes"].contains(
          key,
        ) else {
          raise @json.JsonDecodeError((path, "Unknown limit: " + key))
        }
      }
    }
  }
  { version: wire.version, cases: wire.cases, }
}

///|
pub(all) suberror SuiteError {
  InvalidSuite(String)
} derive(Debug)

///|
/// Validate the entire suite before starting a driver or solver.
pub fn Suite::validate(self : Suite) -> Unit raise SuiteError {
  guard self.version == 1 && !self.cases.is_empty() else {
    raise InvalidSuite("Expected version 1 and at least one case")
  }
  let names : Map[String, Bool] = Map([])
  for case in self.cases {
    guard !case.name.is_empty() &&
      !case.driver.is_empty() &&
      !names.contains(case.name) else {
      raise InvalidSuite("Empty or duplicate case name, or empty driver")
    }
    names.set(case.name, true)
    if case.limits is Some(limits) {
      guard limits.timeout_ms > 0 &&
        limits.memory_mb > 0 &&
        limits.max_query_bytes > 0 &&
        limits.max_output_bytes > 0 else {
        raise InvalidSuite("All resource limits must be positive")
      }
    }
    let bound = case.bound.unwrap_or(8)
    guard bound >= 0 && bound <= 1000000 else {
      raise InvalidSuite("Bound must be in 0..1000000")
    }
    guard !(case.fair.unwrap_or(false) && case.justice is Some(_)) else {
      raise InvalidSuite("Use either fair or justice")
    }
    let target = case.target.unwrap_or("wasm")
    guard target == "wasm" ||
      target == "native" ||
      target == "js" ||
      target == "wasm-gc" else {
      raise InvalidSuite("Invalid target")
    }
    guard !case.require_trigger.unwrap_or(false) ||
      case.property is @model_check.Response(_, _) else {
      raise InvalidSuite("require_trigger needs a response property")
    }
    if case.complete.unwrap_or(false) {
      guard case.bound is None && case.limits is None else {
        raise InvalidSuite(
          "Complete checks do not accept bound or solver limits",
        )
      }
      guard case.property is @model_check.Response(_, _) ||
        (!case.fair.unwrap_or(false) && case.justice is None) else {
        raise InvalidSuite("Complete fairness requires response")
      }
      let valid = match case.property {
        Reachability(_) =>
          case.expect == Witness || case.expect == CompleteUnreachable
        Safety(_) | Deadlock(_) | Response(_, _) =>
          case.expect == Counterexample || case.expect == CompleteSafe
      }
      guard valid else {
        raise InvalidSuite("Invalid complete-model expectation")
      }
      continue
    }
    let valid = match case.property {
      Reachability(_) =>
        case.expect == Witness || case.expect == BoundedUnreachable
      Safety(_) | Deadlock(_) =>
        case.expect == Counterexample || case.expect == BoundedSafe
      Response(_, _) =>
        bound > 0 &&
        (case.expect == Counterexample || case.expect == BoundedSafe)
    }
    guard valid else {
      raise InvalidSuite("Expectation does not match the property")
    }
  }
}
