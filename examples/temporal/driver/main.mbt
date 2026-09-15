///|
struct Config {
  allow_drop : Bool
} derive(@json.FromJson)

///|
fn main {
  @model_driver.serve((config : Config) => @explorer.client(config.allow_drop))
}
