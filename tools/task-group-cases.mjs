// Shared expectations for the Z3 and Apalache drivers.
export const taskGroupChecks = [
  {name: "safety", property: "safe", kind: "safety", expected: "no-counterexample-up-to-bound"},
  {name: "normal-exit", property: "normal_return", kind: "reachability", expected: "witness"},
  {name: "error-exit", property: "failed_return", kind: "reachability", expected: "witness"},
  {name: "closing-unfair", property: "closing-response", expected: "counterexample"},
  {name: "closing-fair", property: "closing-response", fair: true, expected: "no-counterexample-up-to-bound"},
  {name: "body-return-can-wait", property: "body-response", fair: true, expected: "counterexample"},
  {name: "no-wait-fair", property: "closing-response", fair: true, policy: 2, expected: "no-counterexample-up-to-bound"},
  {name: "allow-failure-fair", property: "closing-response", fair: true, policy: 4, expected: "no-counterexample-up-to-bound"},
  {name: "broken-early-join", property: "no_orphans", kind: "safety", fault: 1, expected: "counterexample"},
  {name: "broken-leaked-resource", property: "resources", kind: "safety", fault: 2, expected: "counterexample"},
  {name: "broken-lost-cancel", property: "closing-response", fair: true, fault: 3, expected: "counterexample"},
];
