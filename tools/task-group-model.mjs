import {createModelClient} from "./model-client.mjs";

export const taskGroupClient = createModelClient({
  driver: "task_group/driver", defaults: {policy: 0, fault: 0},
});

export function loadTaskGroup(policy = 0, fault = 0) {
  return taskGroupClient.load({policy, fault});
}

export function taskGroupProperty(name) {
  if (name === "closing-response" || name === "body-response") {
    return {kind: "response", trigger: name === "closing-response" ? "closing" : "body_done", goal: "returned"};
  }
  return {kind: ["returned", "normal_return", "failed_return"].includes(name) ? "reachability" : "safety", predicate: name};
}

// Existing commands keep their convenience options; transport and evaluation are shared.
export function replayTaskGroup(witnesses, {policy = 0, fault = 0, property = "safe", fair = false} = {}) {
  return taskGroupClient.replay(witnesses, {config: {policy, fault}, property: taskGroupProperty(property),
    justice: fair ? loadTaskGroup(policy, fault).justice : []});
}
