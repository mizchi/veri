///|
pub(all) suberror RunnerError {
  InvalidResponse(String)
  SolverFailure(String)
  ReplayRejected
} derive(Debug)

///|
/// Process configuration only. Model configuration is a separate JSON value.
pub(all) struct Driver {
  driver_pkg : String
  module_dir : String
  target : String
} derive(Debug)

///|
struct Response[T] {
  version : Int
  result : T
} derive(@json.FromJson)

///|
pub(all) struct CheckResult {
  result : String
  bound : Int
  witness : @model_check.Witness?
} derive(ToJson)

///|
async fn[T : @json.FromJson] Driver::request(
  self : Driver,
  mode : String,
  config : Json,
  property : @model_check.Property?,
  justice : Array[Int],
  witnesses : Array[@model_check.Witness],
) -> T {
  let fields : Map[String, Json] = {
    "version": 1,
    "mode": mode.to_json(),
    "config": config,
    "justice": justice.to_json(),
    "witnesses": witnesses.to_json(),
  }
  if property is Some(property) {
    fields.set("property", property.to_json())
  }
  let input = fields.to_json().stringify()
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
  justice? : Array[Int] = [],
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
async fn run_z3(z3 : String, source : String) -> String {
  let output = @shell.Cmd(z3, ["-in", "-smt2", "-T:60"], stdin=Text(source)).output(
    timeout_ms=65000,
    max_output_bytes=16 * 1024 * 1024,
  )
  output.check()
  output.stdout()
}

///|
/// Search each finite prefix, then require graph evaluation and actual model replay.
pub async fn Driver::check(
  self : Driver,
  config : Json,
  property : @model_check.Property,
  bound? : Int = 8,
  justice? : Array[Int] = [],
  z3? : String = "z3",
) -> CheckResult {
  let model = self.load(config)
  @smt.validate_query(model, property, bound, justice~)
  let response = property is @model_check.Response(_, _)
  for depth = (if response { 1 } else { 0 }); depth <= bound; depth = depth + 1 {
    let source = @smt.query_source(model, property, depth, justice~)
    let status = run_z3(z3, source + "(check-sat)\n").trim().to_owned()
    match status {
      "unsat" => continue
      "sat" => ()
      _ => raise SolverFailure("Expected sat or unsat, got: " + status)
    }
    let output = run_z3(
      z3,
      source + "(check-sat)\n" + @smt.value_command(depth, response~),
    )
    let witness = @smt.decode_witness(output, depth, response~)
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
      bound: depth,
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
