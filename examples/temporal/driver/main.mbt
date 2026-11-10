///|
#derive(@json.FromJson)
struct Config {
  allow_drop : Bool
}

///|
fn main {
  @model_driver.serve((config : Config) => @explorer.client(config.allow_drop))
}
