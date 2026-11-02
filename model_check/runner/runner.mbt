///|
pub(all) suberror RunnerError {
  InvalidResponse(String)
  SolverFailure(String)
  ReplayRejected
  TriggerUnreachable(Int32)
  TriggerUnreachableInCompleteModel
} derive(Debug)

///|
pub extend RunnerError with @debug.Debug::{to_repr}

///|
/// Process configuration only. Model configuration is a separate JSON value.
pub(all) struct Driver {
  driver_pkg : String
  module_dir : String
  target : String
} derive(Debug, ToJson, @json.FromJson)

///|
pub extend Driver with @debug.Debug::{to_repr}

///|
pub extend Driver with ToJson::{to_json}

///|
pub extend Driver with @json.FromJson::{from_json}

///|
struct Response[T] {
  version : Int32
  result : T
} derive(@json.FromJson)

///|
pub extend Response with @json.FromJson::{from_json}

///|
pub(all) struct CheckResult {
  result : String
  bound : Int32
  witness : @model_check.Witness?
} derive(ToJson, @json.FromJson)

///|
pub extend CheckResult with ToJson::{to_json}

///|
pub extend CheckResult with @json.FromJson::{from_json}

///|
async fn[T : @json.FromJson] Driver::request(
  self : Driver,
  mode : String,
  config : Json,
  property : @model_check.Property?,
  justice : Array[Int32],
  witnesses : Array[@model_check.Witness],
) -> T {
  let fields : Map[String, Json] = {
    "version": 1,
    "mode": Json(mode),
    "config": config,
    "justice": Json(justice),
    "witnesses": Json(witnesses),
  }
  if property is Some(property) {
    fields.set("property", property.to_json())
  }
  let input = Json(fields).stringify()
  let output = @shell.Cmd("moon", [
    "-C",
    self.module_dir,
    "run",
    self.driver_pkg,
    "--target",
    self.target,
    "--deny-warn",
    "--",
    input,
  ]).output(timeout_ms=60000, max_output_bytes=16 * 1024 * 1024)
  output.check()
  let response : Response[T] = @json.from_json(@json.parse(output.stdout()[:]))
  guard response.version == 1 else {
    raise InvalidResponse("Unsupported protocol version")
  }
  response.result
}

///|
pub async fn Driver::load(
  self : Driver,
  config : Json,
) -> @model_check.Model[Json] {
  let model = self.request("export", config, None, [], [])
  @smt.validate(model)
  model
}

///|
pub async fn Driver::replay(
  self : Driver,
  config : Json,
  property : @model_check.Property,
  witnesses : Array[@model_check.Witness],
  justice~ : Array[Int32] = [],
) -> Array[Bool] {
  let accepted : Array[Bool] = self.request(
    "replay",
    config,
    Some(property),
    justice,
    witnesses,
  )
  guard accepted.length() == witnesses.length() else {
    raise InvalidResponse("Replay result length")
  }
  accepted
}

///|
/// Search each finite prefix, then require graph evaluation and actual model replay.
pub async fn Driver::check(
  self : Driver,
  config : Json,
  property : @model_check.Property,
  bound~ : Int32 = 8,
  justice~ : Array[Int32] = [],
  z3~ : String = "z3",
  require_trigger~ : Bool = false,
  limits~ : @model_check.Limits = @model_check.Limits::new(),
) -> CheckResult {
  self.check_loaded(
    self.load(config),
    config,
    property,
    bound~,
    justice~,
    z3~,
    require_trigger~,
    limits~,
  )
}

///|
async fn Driver::check_loaded(
  self : Driver,
  model : @model_check.Model[Json],
  config : Json,
  property : @model_check.Property,
  bound~ : Int32,
  justice~ : Array[Int32],
  z3~ : String,
  require_trigger~ : Bool = false,
  limits~ : @model_check.Limits = @model_check.Limits::new(),
) -> CheckResult {
  @smt.validate_query(model, property, bound, justice~)
  if require_trigger {
    guard property is @model_check.Response(trigger, _) else {
      raise InvalidResponse("require_trigger needs response")
    }
    let coverage = self.check_loaded(
      model,
      config,
      @model_check.Reachability(trigger),
      bound~,
      justice=[],
      z3~,
      limits~,
    )
    guard coverage.witness is Some(_) else { raise TriggerUnreachable(bound) }
  }
  if solve(model, property, bound, justice, z3, limits) is Some(witness) {
    guard @smt.evaluate(model, property, witness, justice~) else {
      raise ReplayRejected
    }
    guard self.replay(config, property, [witness], justice~) == [true] else {
      raise ReplayRejected
    }
    return {
      result: if property is @model_check.Reachability(_) {
        "witness"
      } else {
        "counterexample"
      },
      bound: witness.actions.length(),
      witness: Some(witness),
    }
  }
  {
    result: if property is @model_check.Reachability(_) {
      "unreachable-up-to-bound"
    } else {
      "no-counterexample-up-to-bound"
    },
    bound,
    witness: None,
  }
}

///|
pub async fn Driver::check_complete(
  self : Driver,
  config : Json,
  property : @model_check.Property,
  justice~ : Array[Int32] = [],
  require_trigger~ : Bool = false,
) -> CheckResult {
  self.check_complete_loaded(
    self.load(config),
    config,
    property,
    justice~,
    require_trigger~,
  )
}

///|
async fn Driver::check_complete_loaded(
  self : Driver,
  model : @model_check.Model[Json],
  config : Json,
  property : @model_check.Property,
  justice~ : Array[Int32],
  require_trigger~ : Bool,
) -> CheckResult {
  if require_trigger {
    guard property is @model_check.Response(trigger, _) else {
      raise InvalidResponse("require_trigger needs response")
    }
    let coverage = @smt.exhaustive(model, @model_check.Reachability(trigger))
    let witness = match coverage.witness {
      None => raise TriggerUnreachableInCompleteModel
      Some(w) => w
    }
    guard self.replay(config, @model_check.Reachability(trigger), [witness]) ==
      [true] else {
      raise ReplayRejected
    }
  }
  let result = @smt.exhaustive(model, property, justice~)
  if result.witness is Some(witness) {
    guard @smt.evaluate(model, property, witness, justice~) &&
      self.replay(config, property, [witness], justice~) == [true] else {
      raise ReplayRejected
    }
  }
  {
    result: match (property, result.witness) {
      (Reachability(_), Some(_)) => "witness"
      (_, Some(_)) => "counterexample"
      (Reachability(_), None) => "unreachable-in-complete-model"
      (_, None) => "safe-for-complete-model"
    },
    bound: result.witness
    .map(w => w.actions.length())
    .unwrap_or(result.max_depth),
    witness: result.witness,
  }
}
