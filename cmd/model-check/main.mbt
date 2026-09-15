///|
suberror UsageError {
  InvalidArgument(String)
} derive(Debug)

///|
let help : String =
  #|veri model-check: export, check, or replay a MoonBit model
  #|
  #|Usage: veri <export|check|replay> <driver-package> [options]
  #|  --module DIR         Model module directory (default: .)
  #|  --config JSON        Model-specific configuration (default: {})
  #|  --config-file FILE   Read model configuration from a JSON file
  #|  --safety P           Find a state violating predicate P
  #|  --reachable P        Find a state satisfying predicate P
  #|  --response P Q       Find a lasso violating G(P => F Q)
  #|  --bound N            SMT transition bound, 0..16 (default: 8)
  #|  --justice JSON       Explicit weak-fairness action IDs (default: [])
  #|  --fair               Use the model's suggested justice actions
  #|  --witnesses FILE     JSON array of {states, actions, loop_start?} for replay
  #|  --target TARGET      Model driver target (default: wasm)
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
  let mut witnesses_path : String? = None
  let mut z3 = "z3"
  let mut i = 2
  while i < args.length() {
    let flag = args[i]
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
      "--safety" | "--reachable" | "--response" => {
        guard property is None else {
          raise InvalidArgument("Specify exactly one property")
        }
        property = Some(
          match flag {
            "--safety" => @model_check.Safety(value)
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
        guard bound >= 0 && bound <= 16 else {
          raise InvalidArgument("Bound must be in 0..16")
        }
      }
      "--justice" => {
        guard !justice_set else { raise InvalidArgument("Duplicate --justice") }
        justice = @json.from_json(@json.parse(value[:]))
        justice_set = true
      }
      "--witnesses" => witnesses_path = Some(value)
      "--z3" => z3 = value
      _ => raise InvalidArgument("Unknown option: " + flag)
    }
    i += 2
  }
  guard !(fair && justice_set) else {
    raise InvalidArgument("Use either --fair or --justice")
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
  if fair {
    justice = driver.load(config).justice
  }
  if mode == "check" {
    guard witnesses_path is None else {
      raise InvalidArgument("Check does not take --witnesses")
    }
    return driver.check(config, property, bound~, justice~, z3~).to_json()
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
  let result = execute(args) catch {
    error => {
      @stdio.stderr.write("veri: " + @debug.to_string(error) + "\n")
      abort("Model check failed")
    }
  }
  println(result.stringify())
}
