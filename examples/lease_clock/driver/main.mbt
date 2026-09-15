///|
struct Config {
  variant : Int
  bound : Int
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
    guard config.bound >= 0 && config.bound <= 16 else {
      raise InvalidConfig("Invalid lease exploration depth")
    }
    @explorer.explore(variant, config.bound).client(variant)
  })
}
