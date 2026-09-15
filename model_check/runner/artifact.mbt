///|
/// The full finite model is the identity: replay compares it, not a lossy hash.
pub(all) struct Bundle {
  version : Int
  driver : Driver
  config : Json
  property : @model_check.Property
  justice : Array[Int]
  require_trigger : Bool
  limits : @model_check.Limits
  // Absent in older version 1 bounded bundles.
  complete : Bool?
  model : @model_check.Model[Json]
  result : CheckResult
} derive(ToJson, @json.FromJson)

///|
pub async fn Driver::record(
  self : Driver,
  config : Json,
  property : @model_check.Property,
  bound? : Int = 8,
  justice? : Array[Int] = [],
  z3? : String = "z3",
  require_trigger? : Bool = false,
  limits? : @model_check.Limits = @model_check.Limits::new(),
) -> Bundle {
  let model = self.load(config)
  let result = self.check_loaded(
    model,
    config,
    property,
    bound~,
    justice~,
    z3~,
    require_trigger~,
    limits~,
  )
  {
    version: 1,
    driver: self,
    config,
    property,
    justice,
    require_trigger,
    limits,
    complete: None,
    model,
    result,
  }
}

///|
pub async fn Driver::record_complete(
  self : Driver,
  config : Json,
  property : @model_check.Property,
  justice? : Array[Int] = [],
  require_trigger? : Bool = false,
) -> Bundle {
  let model = self.load(config)
  let result = self.check_complete_loaded(
    model,
    config,
    property,
    justice~,
    require_trigger~,
  )
  {
    version: 1,
    driver: self,
    config,
    property,
    justice,
    require_trigger,
    limits: @model_check.Limits::new(),
    complete: Some(true),
    model,
    result,
  }
}

///|
fn Bundle::witness(self : Bundle) -> @model_check.Witness raise {
  guard self.version == 1 else {
    raise InvalidResponse("Unsupported bundle version")
  }
  if self.complete.unwrap_or(false) {
    guard !(self.model.exploration is Some(scope) && !scope.complete) else {
      raise InvalidResponse("Complete bundle contains a truncated model")
    }
    guard self.justice.is_empty() ||
      self.property is @model_check.Response(_, _) else {
      raise InvalidResponse("Complete fairness requires response")
    }
  }
  let witness = match self.result.witness {
    Some(w) => w
    None => raise InvalidResponse("Bundle has no witness")
  }
  let expected = if self.property is @model_check.Reachability(_) {
    "witness"
  } else {
    "counterexample"
  }
  guard self.result.result == expected &&
    self.result.bound == witness.actions.length() else {
    raise InvalidResponse("Inconsistent bundle result")
  }
  guard @smt.evaluate(self.model, self.property, witness, justice=self.justice) else {
    raise ReplayRejected
  }
  witness
}

///|
pub fn Bundle::explain(self : Bundle) -> Json raise {
  @smt.describe(self.model, self.property, self.witness(), justice=self.justice)
}

///|
/// Verify model identity and rerun the actual step/holds functions. No solver is needed.
pub async fn Bundle::replay(self : Bundle, module_dir? : String) -> Unit {
  let witness = self.witness()
  let driver = match module_dir {
    None => self.driver
    Some(module_dir) => { ..self.driver, module_dir, }
  }
  let current = driver.load(self.config)
  guard current.to_json() == self.model.to_json() else {
    raise InvalidResponse("Model changed since this bundle was recorded")
  }
  guard driver.replay(
      self.config,
      self.property,
      [witness],
      justice=self.justice,
    ) ==
    [true] else {
    raise ReplayRejected
  }
}
