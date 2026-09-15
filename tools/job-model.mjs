import {createModelClient} from "./model-client.mjs";

export const jobClient = createModelClient({driver: "temporal/driver", defaults: {allow_drop: false}});

export function loadJob(allowDrop = false) {
  return jobClient.load({allow_drop: allowDrop});
}

export function replayJob(witnesses, {allowDrop = false, fair = false,
  property = {kind: "response", trigger: "pending", goal: "done"}} = {}) {
  return jobClient.replay(witnesses, {config: {allow_drop: allowDrop}, property, justice: fair ? [1] : []});
}
