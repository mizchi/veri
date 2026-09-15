// Independent imperative oracle for tests. Node IDs: A=0, B=1.
// Semantics: the two modules in the Quint source linked by the example README.
export const leaseActions = ["advance-time", "renew-a", "renew-b", "fence-a", "fence-b",
  "take-over-a", "take-over-b", "publish-owner"];

export function referenceInitial() {
  return {now: 0, a: {expires: 3, elapsed: 0, held: true, resident_epoch: 1},
    b: {expires: 4, elapsed: 0, held: true, resident_epoch: 0}, owner: 0, epoch: 1};
}

export function referenceStep(before, action, repaired) {
  const s = structuredClone(before), nodes = [s.a, s.b];
  if (action === 0) {
    if (s.now === 6) return null;
    s.now++;
    nodes.forEach(n => n.elapsed++);
  } else if (action <= 2) {
    const id = action - 1, n = nodes[id];
    if (!n.held || (repaired && n.elapsed >= 3)) return null;
    n.expires = s.now + id + 3;
    n.elapsed = 0;
  } else if (action <= 4) {
    const n = nodes[action - 3];
    if (!n.held || n.elapsed < (repaired ? 3 : 4)) return null;
    n.held = false;
    n.resident_epoch = 0;
  } else if (action <= 6) {
    const id = action - 5, n = nodes[id];
    if (!n.held || id === s.owner || (repaired && n.elapsed >= 3) ||
        s.now + id < nodes[s.owner].expires + (repaired ? 1 : 0)) return null;
    s.owner = id;
    s.epoch++;
  } else {
    const n = nodes[s.owner];
    if (!n.held || n.resident_epoch === s.epoch || (repaired && n.elapsed >= 3)) return null;
    n.resident_epoch = s.epoch;
  }
  return s;
}

export function referenceWriters(s, repaired) {
  return [s.a, s.b].map(n => n.held && n.resident_epoch > 0 && (!repaired || n.elapsed < 3));
}

export function stateKey(s) {
  return JSON.stringify([s.now, s.owner, s.epoch,
    ...[s.a, s.b].flatMap(n => [n.expires, n.elapsed, n.held, n.resident_epoch])]);
}

export function referenceStates(repaired, bound) {
  const initial = referenceInitial();
  const states = new Map([[stateKey(initial), {state: initial, depth: 0}]]);
  let layer = [initial];
  for (let depth = 1; depth <= bound && layer.length; depth++) {
    const nextLayer = [];
    for (const s of layer) for (let action = 0; action < leaseActions.length; action++) {
      const next = referenceStep(s, action, repaired);
      if (next === null || states.has(stateKey(next))) continue;
      states.set(stateKey(next), {state: next, depth});
      nextLayer.push(next);
    }
    layer = nextLayer;
  }
  return states;
}
