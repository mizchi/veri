///|
/// Check a finite safety/reachability certificate or an infinite response lasso.
/// Every edge and fairness guard calls step again; exported edges and predicates
/// are never used as evidence. This evaluator is tested, not a moon prove theorem.
pub fn[S : Eq, E, Snapshot] Client::accepts(
  self : Client[S, E, Snapshot],
  property : Property,
  witness : Witness,
  justice? : Array[Int] = [],
) -> Bool {
  let ids = witness.states
  let count = witness.actions.length()
  if ids.length() != count + 1 || ids[0] != self.model.initial {
    return false
  }
  for id in ids {
    if id < 0 || id >= self.states.length() {
      return false
    }
  }
  if self.states[ids[0]] != self.initial {
    return false
  }
  if self.model.exploration is Some(scope) && !scope.complete {
    if count > scope.max_depth || property is Response(_, _) {
      return false
    }
  }
  for i, action in justice {
    if action < 0 || action >= self.events.length() {
      return false
    }
    for j = 0; j < i; j = j + 1 {
      if justice[j] == action {
        return false
      }
    }
  }
  let names = match property {
    Safety(name) | Reachability(name) => [name]
    Response(trigger, goal) => [trigger, goal]
  }
  for name in names {
    if !self.model.predicates.contains(name) {
      return false
    }
    for id in ids {
      if (self.holds)(self.states[id], name) is None {
        return false
      }
    }
  }
  for i, action in witness.actions {
    if action < 0 || action >= self.events.length() {
      return false
    }
    if (self.step)(self.states[ids[i]], self.events[action]) !=
      Some(self.states[ids[i + 1]]) {
      return false
    }
  }
  match property {
    Safety(name) =>
      return witness.loop_start is None &&
        ids.any(id => (self.holds)(self.states[id], name) == Some(false))
    Reachability(name) =>
      return witness.loop_start is None &&
        (self.holds)(self.states[ids[count]], name) == Some(true)
    Response(_, _) => ()
  }
  let start_loop = match witness.loop_start {
    Some(i) => i
    None => return false
  }
  if start_loop < 0 || start_loop >= count || ids[count] != ids[start_loop] {
    return false
  }
  for action in justice {
    let mut satisfied = false
    for i = start_loop; i < count; i = i + 1 {
      let state = self.states[ids[i]]
      match (self.step)(state, self.events[action]) {
        None => satisfied = true
        Some(next) =>
          if next == state ||
            (witness.actions[i] == action && ids[i] != ids[i + 1]) {
            satisfied = true
          }
      }
    }
    if !satisfied {
      return false
    }
  }
  guard property is Response(trigger, goal) else { return false }
  for start = 0; start < count; start = start + 1 {
    if (self.holds)(self.states[ids[start]], trigger) != Some(true) {
      continue
    }
    let visited = Array::make(count, false)
    let mut i = start
    let mut reached = false
    while !visited[i] {
      visited[i] = true
      if (self.holds)(self.states[ids[i]], goal) == Some(true) {
        reached = true
        break
      }
      i = if i + 1 == count { start_loop } else { i + 1 }
    }
    if !reached {
      return true
    }
  }
  false
}
