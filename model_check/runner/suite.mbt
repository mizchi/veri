///|
pub(all) struct CaseReport {
  name : String
  expected : @suite.Outcome
  passed : Bool
  result : CheckResult?
  error : String?
} derive(ToJson)

///|
pub(all) struct SuiteReport {
  version : Int
  passed : Bool
  cases : Array[CaseReport]
} derive(ToJson)

///|
/// Relative module paths are resolved against the suite file's directory.
pub async fn run_suite(
  suite : @suite.Suite,
  base_dir? : String = ".",
  z3? : String = "z3",
) -> SuiteReport {
  suite.validate()
  let reports = []
  for case in suite.cases {
    let result : CheckResult? = None
    let error : String? = None
    let (result, error) = try {
      let module_dir = case.module_dir.unwrap_or(".")
      let driver : Driver = {
        driver_pkg: case.driver,
        module_dir: if module_dir.has_prefix("/") {
          module_dir
        } else {
          base_dir + "/" + module_dir
        },
        target: case.target.unwrap_or("wasm"),
      }
      let config = case.config.unwrap_or(Json::empty_object())
      let justice = if case.fair.unwrap_or(false) {
        driver.load(config).justice
      } else {
        case.justice.unwrap_or([])
      }
      (
        Some(
          if case.complete.unwrap_or(false) {
            driver.check_complete(
              config,
              case.property,
              justice~,
              require_trigger=case.require_trigger.unwrap_or(false),
            )
          } else {
            driver.check(
              config,
              case.property,
              bound=case.bound.unwrap_or(8),
              justice~,
              z3~,
              require_trigger=case.require_trigger.unwrap_or(false),
              limits=case.limits.unwrap_or(@model_check.Limits::new()),
            )
          },
        ),
        error,
      )
    } catch {
      e => (result, Some(@debug.to_string(e)))
    }
    reports.push({
      name: case.name,
      expected: case.expect,
      passed: result is Some(value) && value.result == case.expect.code(),
      result,
      error,
    })
  }
  { version: 1, passed: reports.all(report => report.passed), cases: reports, }
}
