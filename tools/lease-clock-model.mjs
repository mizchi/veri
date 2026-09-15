import {createModelClient} from "./model-client.mjs";

export const leaseClockClient = createModelClient({
  driver: "lease_clock/driver", defaults: {variant: 0, bound: 8},
});

export function loadLeaseClock(variant = 0, bound = 8) {
  return leaseClockClient.load({variant, bound});
}

export function replayLeaseClock(witnesses, {variant = 0, bound = 8, property = "single_writer"} = {}) {
  return leaseClockClient.replay(witnesses, {config: {variant, bound},
    property: {kind: property === "b_writer" ? "reachability" : "safety", predicate: property}});
}
