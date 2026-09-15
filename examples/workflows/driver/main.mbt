///|
struct Config {
  mode : Int
} derive(@json.FromJson)

///|
fn main {
  @model_driver.serve((config : Config) => {
    let spec : @model_check.Spec[Int, Int, Int] = {
      initial: 0,
      actions: [("finish", 1)],
      step: (state, _) => {
        if state == 0 || config.mode == 2 {
          Some(1)
        } else {
          None
        }
      },
      predicates: [
        ("terminal", s => config.mode == 0 && s == 1),
        ("pending", s => s == 0),
        ("never", _ => false),
      ],
      snapshot: s => s,
      justice: [],
    }
    @model_check.build_client(spec, max_depth=2)
  })
}
