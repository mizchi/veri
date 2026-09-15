///|
struct Config {
  policy : Int
  fault : Int
} derive(@json.FromJson)

///|
suberror ConfigError {
  InvalidConfig(String)
} derive(Debug)

///|
fn main {
  @model_driver.serve((config : Config) => {
    guard config.policy >= 0 && config.policy < 16 else {
      raise InvalidConfig("Invalid policy")
    }
    let policy = @explorer.policy(config.policy)
    let fault = match config.fault {
      0 => @explorer.Correct
      1 => @explorer.EarlyJoin
      2 => @explorer.LeakCleanup
      3 => @explorer.LostCancel
      _ => raise InvalidConfig("Invalid fault")
    }
    @explorer.explore(policy, fault).client(policy, fault)
  })
}
