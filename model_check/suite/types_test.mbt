///|
test "suite rejects unknown options before executing any case" {
  let input : Json = {
    "version": 1,
    "cases": [
      {
        "name": "invalid",
        "driver": "ignored",
        "expect": "no-counterexample-up-to-bound",
        "property": { "kind": "safety", "predicate": "safe" },
        "requireTrigger": true,
      },
    ],
  }
  assert_true(
    try {
      let _ : @suite.Suite = @json.from_json(input)
      false
    } catch {
      _ => true
    },
  )
}
