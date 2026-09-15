///|
suberror UsageError {
  InvalidArgument(String)
} derive(Debug)

///|
let help : String =
  #|veri model-check: export, check, or replay a MoonBit model
  #|
  #|Usage: veri <export|check|replay> <driver-package> [options]
  #|       veri test <suite.json> [--z3 PATH]
  #|       veri <explain|replay-file> <bundle.json> [--module DIR]
  #|  --module DIR         Model module directory (default: .)
  #|  --config JSON        Model-specific configuration (default: {})
  #|  --config-file FILE   Read model configuration from a JSON file
  #|  --safety P           Find a state violating predicate P
  #|  --reachable P        Find a state satisfying predicate P
  #|  --response P Q       Find a lasso violating G(P => F Q)
  #|  --deadlock TERMINAL  Find a nonterminal state with no enabled event
  #|  --complete           Exhaust a complete finite graph, including fair response
  #|  --require-trigger    Require a reachable response trigger in the checked scope
  #|  --bound N            SMT transition bound, 0..1000000 (default: 8)
  #|  --justice JSON       Explicit weak-fairness action IDs (default: [])
  #|  --fair               Use the model's suggested justice actions
  #|  --witnesses FILE     JSON array of {states, actions, loop_start?} for replay
  #|  --target TARGET      Model driver target (default: wasm)
  #|  --timeout-ms N      Total solver session timeout (default: 60000)
  #|  --memory-mb N       Z3 memory limit (default: 512)
  #|  --max-query-bytes N Limit generated SMT per session (default: 16777216)
  #|  --max-output-bytes N Limit solver output per session (default: 16777216)
  #|  --save FILE          Save configuration, model, and result for replay
  #|  --z3 PATH            Z3 executable (default: z3)
  #|
  #|Results are JSON on stdout. Counterexamples are successful query results.
  #|Invalid inputs, solver failures, and failed automatic replay exit unsuccessfully.

///|
async fn execute(args : Array[String]) -> Json {
  guard args.length() >= 2 else {
    raise InvalidArgument("Expected command and driver package")
  }
  let mode = args[0]
  if mode == "explain" || mode == "replay-file" {
    guard args.length() == 2 ||
      (mode == "replay-file" && args.length() == 4 && args[2] == "--module") else {
      raise InvalidArgument(
        "Usage: explain bundle.json | replay-file bundle.json [--module DIR]",
      )
    }
    let bundle : @runner.Bundle = @json.from_json(
      @json.parse(@fs.read_file(args[1]).text()[:]),
    )
    if mode == "explain" {
      return bundle.explain()
    }
    if args.length() == 4 {
      bundle.replay(module_dir=args[3])
    } else {
      bundle.replay()
    }
    return { "accepted": true }
  }
  guard mode == "export" || mode == "check" || mode == "replay" else {
    raise InvalidArgument("Unknown command: " + mode)
  }
  let driver_pkg = args[1]
  let mut module_dir = "."
  let mut target = "wasm"
  let mut config = Json::empty_object()
  let mut config_set = false
  let mut property : @model_check.Property? = None
  let mut bound = 8
  let mut justice : Array[Int] = []
  let mut justice_set = false
  let mut fair = false
  let mut require_trigger = false
  let mut complete = false
  let mut witnesses_path : String? = None
  let mut z3 = "z3"
  let mut save_path : String? = None
  let mut limits = @model_check.Limits::new()
  let mut limits_set = false
  let mut i = 2
  while i < args.length() {
    let flag = args[i]
    if flag == "--complete" {
      guard !complete else { raise InvalidArgument("Duplicate --complete") }
      complete = true
      i += 1
      continue
    }
    if flag == "--require-trigger" {
      guard !require_trigger else {
        raise InvalidArgument("Duplicate --require-trigger")
      }
      require_trigger = true
      i += 1
      continue
    }
    if flag == "--fair" {
      guard !fair else { raise InvalidArgument("Duplicate --fair") }
      fair = true
      i += 1
      continue
    }
    guard i + 1 < args.length() else {
      raise InvalidArgument("Missing value for " + flag)
    }
    let value = args[i + 1]
    if flag == "--timeout-ms" ||
      flag == "--memory-mb" ||
      flag == "--max-query-bytes" ||
      flag == "--max-output-bytes" {
      limits_set = true
    }
    match flag {
      "--module" => module_dir = value
      "--target" => {
        guard value == "wasm" ||
          value == "native" ||
          value == "js" ||
          value == "wasm-gc" else {
          raise InvalidArgument("Invalid target")
        }
        target = value
      }
      "--config" | "--config-file" => {
        guard !config_set else {
          raise InvalidArgument("Duplicate model configuration")
        }
        config = @json.parse(
          (if flag == "--config" { value } else { @fs.read_file(value).text() })[:],
        )
        config_set = true
      }
      "--safety" | "--reachable" | "--response" | "--deadlock" => {
        guard property is None else {
          raise InvalidArgument("Specify exactly one property")
        }
        property = Some(
          match flag {
            "--safety" => @model_check.Safety(value)
            "--deadlock" => @model_check.Deadlock(value)
            "--reachable" => @model_check.Reachability(value)
            _ => {
              guard i + 2 < args.length() else {
                raise InvalidArgument("--response needs trigger and goal")
              }
              i += 1
              @model_check.Response(value, args[i + 1])
            }
          },
        )
      }
      "--bound" => {
        bound = @string.parse_int(value[:])
        guard bound >= 0 && bound <= 1000000 else {
          raise InvalidArgument("Bound must be in 0..1000000")
        }
      }
      "--justice" => {
        guard !justice_set else { raise InvalidArgument("Duplicate --justice") }
        justice = @json.from_json(@json.parse(value[:]))
        justice_set = true
      }
      "--witnesses" => witnesses_path = Some(value)
      "--timeout-ms" =>
        limits = { ..limits, timeout_ms: @string.parse_int(value[:]), }
      "--memory-mb" =>
        limits = { ..limits, memory_mb: @string.parse_int(value[:]), }
      "--max-query-bytes" =>
        limits = { ..limits, max_query_bytes: @string.parse_int(value[:]), }
      "--max-output-bytes" =>
        limits = { ..limits, max_output_bytes: @string.parse_int(value[:]), }
      "--z3" => z3 = value
      "--save" => save_path = Some(value)
      _ => raise InvalidArgument("Unknown option: " + flag)
    }
    i += 2
  }
  guard !(fair && justice_set) else {
    raise InvalidArgument("Use either --fair or --justice")
  }
  guard save_path is None || mode == "check" else {
    raise InvalidArgument("--save requires check")
  }
  guard !require_trigger ||
    (mode == "check" && property is Some(@model_check.Response(_, _))) else {
    raise InvalidArgument("--require-trigger requires a response check")
  }
  guard !limits_set || (mode == "check" && !complete) else {
    raise InvalidArgument("Solver limits require a bounded check")
  }
  guard !complete || (mode == "check" && !args.contains("--bound")) else {
    raise InvalidArgument(
      "--complete requires check and cannot combine with --bound",
    )
  }
  let driver : @runner.Driver = { driver_pkg, module_dir, target, }
  if mode == "export" {
    guard property is None && witnesses_path is None && !fair && !justice_set else {
      raise InvalidArgument("Export does not take a property or witnesses")
    }
    return driver.load(config).to_json()
  }
  let property = match property {
    Some(p) => p
    None => raise InvalidArgument("A property is required")
  }
  guard !complete ||
    !(fair || justice_set) ||
    property is @model_check.Response(_, _) else {
    raise InvalidArgument("Complete fairness requires --response")
  }
  if fair {
    justice = driver.load(config).justice
  }
  if mode == "check" {
    guard witnesses_path is None else {
      raise InvalidArgument("Check does not take --witnesses")
    }
    if save_path is Some(path) {
      let driver : @runner.Driver = {
        ..driver,
        module_dir: @fs.realpath(module_dir[:]),
      }
      let bundle = if complete {
        driver.record_complete(config, property, justice~, require_trigger~)
      } else {
        driver.record(
          config,
          property,
          bound~,
          justice~,
          z3~,
          require_trigger~,
          limits~,
        )
      }
      @fs.write_file(path[:], bundle.to_json().stringify(indent=2))
      return bundle.result.to_json()
    }
    if complete {
      return driver
        .check_complete(config, property, justice~, require_trigger~)
        .to_json()
    }
    return driver
      .check(config, property, bound~, justice~, z3~, require_trigger~, limits~)
      .to_json()
  }
  let path = match witnesses_path {
    Some(path) => path
    None => raise InvalidArgument("Replay requires --witnesses")
  }
  let witnesses : Array[@model_check.Witness] = @json.from_json(
    @json.parse(@fs.read_file(path).text()[:]),
  )
  driver.replay(config, property, witnesses, justice~).to_json()
}

///|
async fn main {
  let args = @env.args()[1:].to_owned()
  if args.is_empty() || args == ["--help"] || args == ["-h"] {
    println(help)
    return
  }
  if args[0] == "test" {
    let report = run_suite_command(args) catch {
      error => {
        @stdio.stderr.write("veri: " + @debug.to_string(error) + "\n")
        abort("Invalid suite")
      }
    }
    println(report.to_json().stringify())
    if !report.passed {
      abort("Suite expectations failed")
    }
    return
  }
  let result = execute(args) catch {
    error => {
      @stdio.stderr.write("veri: " + @debug.to_string(error) + "\n")
      abort("Model check failed")
    }
  }
  println(result.stringify())
}

///|
async fn run_suite_command(args : Array[String]) -> @runner.SuiteReport {
  guard args.length() == 2 || (args.length() == 4 && args[2] == "--z3") else {
    raise InvalidArgument("Usage: test suite.json [--z3 PATH]")
  }
  let file = @fs.realpath(args[1][:])
  let mut end = file.length() - 1
  while end > 0 && file[end] != '/' {
    end -= 1
  }
  let suite : @suite.Suite = @json.from_json(
    @json.parse(@fs.read_file(file[:]).text()[:]),
  )
  @runner.run_suite(
    suite,
    base_dir=file[:end].to_owned(),
    z3=if args.length() == 4 { args[3] } else { "z3" },
  )
}
