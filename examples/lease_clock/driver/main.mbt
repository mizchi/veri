///|
struct Config {
  variant : Int
  bound : Int
  max_states : Int?
} derive(@json.FromJson)

///|
suberror ConfigError {
  InvalidConfig(String)
} derive(Debug)

///|
fn main {
  @model_driver.serve((config : Config) => {
    let variant : @lease_clock.Variant = match config.variant {
      0 => Vulnerable
      1 => BoundedSkew
      _ => raise InvalidConfig("Invalid lease model variant")
    }
    guard config.bound >= 0 && config.bound <= 1000000 else {
      raise InvalidConfig("Invalid lease exploration depth")
    }
    @explorer.explore(
      variant,
      config.bound,
      max_states=config.max_states.unwrap_or(4096),
    ).client(variant)
  })
}
