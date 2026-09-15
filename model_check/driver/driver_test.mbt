///|
fn make_client(config : Int) -> @model_check.Client[Int, Int, Int] {
  {
    initial: config,
    states: [config],
    events: [0],
    step: (s, _) => Some(s),
    holds: (s, name) => if name == "valid" { Some(s == config) } else { None },
    model: {
      initial: 0,
      actions: ["tick"],
      states: [config],
      transitions: [[0]],
      predicates: { "valid": [true] },
      justice: [],
      exploration: None,
    },
  }
}

///|
test "shared protocol preserves generic config and finite witnesses" {
  let export_request : Json = {
    "version": 1,
    "mode": "export",
    "config": 7,
    "justice": [],
    "witnesses": [],
  }
  assert_eq(@driver.dispatch(export_request.stringify(), make_client), {
    "version": 1,
    "result": make_client(7).model.to_json(),
  })
  let request : Json = {
    "version": 1,
    "mode": "replay",
    "config": 7,
    "justice": [],
    "property": { "kind": "reachability", "predicate": "valid" },
    "witnesses": [
      { "states": [0], "actions": [] },
      { "states": [1], "actions": [] },
    ],
  }
  assert_eq(@driver.dispatch(request.stringify(), make_client), {
    "version": 1,
    "result": [true, false],
  })
}

///|
test "shared protocol rejects wrong versions configs modes and properties" {
  let requests : Array[Json] = [
    {
      "version": 2,
      "mode": "export",
      "config": 7,
      "justice": [],
      "witnesses": [],
    },
    {
      "version": 1,
      "mode": "export",
      "config": true,
      "justice": [],
      "witnesses": [],
    },
    {
      "version": 1,
      "mode": "invalid",
      "config": 7,
      "justice": [],
      "witnesses": [],
    },
    {
      "version": 1,
      "mode": "replay",
      "config": 7,
      "justice": [],
      "witnesses": [],
    },
    {
      "version": 1,
      "mode": "replay",
      "config": 7,
      "justice": [],
      "witnesses": [],
      "property": { "kind": "response", "predicate": "valid" },
    },
    {
      "version": 1,
      "mode": "replay",
      "config": 7,
      "justice": [],
      "witnesses": [],
      "property": { "kind": "safety", "predicate": "valid", "goal": "valid" },
    },
  ]
  for request in requests {
    let rejected = try {
      ignore(@driver.dispatch(request.stringify(), make_client))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
