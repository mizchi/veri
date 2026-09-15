///|
priv struct Search {
  parent : Array[Int]
  incoming : Array[Int]
  depths : Array[Int]
  order : Array[Int]
}

///|
fn search(
  model : @model_check.Model[Json],
  seeds : Array[Int],
  allowed : Array[Bool],
) -> Search {
  let n = model.states.length()
  let parent = Array::make(n, -1)
  let incoming = Array::make(n, -1)
  let depths = Array::make(n, 0)
  let order = []
  for seed in seeds {
    if allowed[seed] && parent[seed] < 0 {
      parent[seed] = seed
      order.push(seed)
    }
  }
  let mut cursor = 0
  while cursor < order.length() {
    let state = order[cursor]
    for action, next in model.transitions[state] {
      if next >= 0 && allowed[next] && parent[next] < 0 {
        parent[next] = state
        incoming[next] = action
        depths[next] = depths[state] + 1
        order.push(next)
      }
    }
    cursor += 1
  }
  { parent, incoming, depths, order, }
}

///|
fn Search::path(self : Search, target : Int) -> (Array[Int], Array[Int]) {
  let states = [target]
  let actions = []
  let mut state = target
  while self.parent[state] != state {
    actions.push(self.incoming[state])
    state = self.parent[state]
    states.push(state)
  }
  states.rev_in_place()
  actions.rev_in_place()
  (states, actions)
}

///|
/// Iterative Kosaraju on the induced graph; long chains do not consume call stack.
fn components(
  model : @model_check.Model[Json],
  allowed : Array[Bool],
) -> (Array[Int], Array[Array[Int]]) {
  let n = model.states.length()
  let m = model.actions.length()
  let reverse = Array::makei(n, _ => [])
  for state = 0; state < n; state = state + 1 {
    if !allowed[state] {
      continue
    }
    for next in model.transitions[state] {
      if next >= 0 && allowed[next] {
        reverse[next].push(state)
      }
    }
  }
  let seen = Array::make(n, false)
  let next_action = Array::make(n, 0)
  let finish = []
  for root = 0; root < n; root = root + 1 {
    if !allowed[root] || seen[root] {
      continue
    }
    let stack = [root]
    seen[root] = true
    while !stack.is_empty() {
      let state = stack[stack.length() - 1]
      let action = next_action[state]
      if action == m {
        ignore(stack.pop())
        finish.push(state)
      } else {
        next_action[state] += 1
        let next = model.transitions[state][action]
        if next >= 0 && allowed[next] && !seen[next] {
          seen[next] = true
          stack.push(next)
        }
      }
    }
  }
  let membership = Array::make(n, -1)
  let groups = []
  finish.rev_in_place()
  for root in finish {
    if membership[root] >= 0 {
      continue
    }
    let id = groups.length()
    let members = []
    let stack = [root]
    membership[root] = id
    while stack.pop() is Some(state) {
      members.push(state)
      for next in reverse[state] {
        if membership[next] < 0 {
          membership[next] = id
          stack.push(next)
        }
      }
    }
    groups.push(members)
  }
  (membership, groups)
}

///|
priv struct Walk {
  states : Array[Int]
  actions : Array[Int]
}

///|
fn Walk::append(self : Walk, action : Int, next : Int) -> Unit raise ModelError {
  guard self.actions.length() < 1000000 else {
    raise InvalidQuery(
      "Constructed response witness exceeds 1000000 transitions",
    )
  }
  self.actions.push(action)
  self.states.push(next)
}

///|
fn Walk::connect(
  self : Walk,
  model : @model_check.Model[Json],
  target : Int,
  allowed : Array[Bool],
) -> Unit raise ModelError {
  let current = self.states[self.states.length() - 1]
  if current == target {
    return
  }
  let tree = search(model, [current], allowed)
  guard tree.parent[target] >= 0 else { raise InvalidModel("Broken SCC path") }
  let (states, actions) = tree.path(target)
  for i, action in actions {
    self.append(action, states[i + 1])
  }
}

///|
/// G(trigger => F goal) fails iff some reachable unanswered trigger leads to
/// a goal-free cyclic SCC with a closed walk satisfying every justice action.
/// Fairness follows Client::accepts: disabled/stuttering actions discharge it;
/// otherwise the walk must take a state-changing edge bearing that action.
fn exhaustive_response(
  model : @model_check.Model[Json],
  trigger : String,
  goal : String,
  justice : Array[Int],
) -> ExhaustiveResult raise ModelError {
  let n = model.states.length()
  let reachable = search(model, [model.initial], Array::make(n, true))
  let pending = model.predicates.get(trigger).unwrap()
  let done = model.predicates.get(goal).unwrap()
  let seeds = reachable.order.filter(state => pending[state] && !done[state])
  let unanswered = search(model, seeds, done.map(value => !value))
  let (membership, groups) = components(
    model,
    unanswered.parent.map(id => id >= 0),
  )
  let max_depth = reachable.depths[reachable.order[reachable.order.length() - 1]]
  for id, members in groups {
    let entry = members[0]
    let cyclic = members.length() > 1 ||
      model.transitions[entry].contains(entry)
    if !cyclic {
      continue
    }
    let evidence : Array[(Int, Int)] = []
    for action in justice {
      for state in members {
        let next = model.transitions[state][action]
        if next < 0 || next == state {
          evidence.push((state, -1))
          break
        }
        if membership[next] == id {
          evidence.push((state, action))
          break
        }
      }
    }
    if evidence.length() != justice.length() {
      continue
    }
    let (suffix_states, suffix_actions) = unanswered.path(entry)
    let (prefix_states, prefix_actions) = reachable.path(suffix_states[0])
    let walk : Walk = { states: [model.initial], actions: [], }
    for i, action in prefix_actions {
      walk.append(action, prefix_states[i + 1])
    }
    for i, action in suffix_actions {
      walk.append(action, suffix_states[i + 1])
    }
    let loop_start = walk.actions.length()
    let in_component = membership.map(component => component == id)
    for (state, action) in evidence {
      walk.connect(model, state, in_component)
      if action >= 0 {
        walk.append(action, model.transitions[state][action])
      }
    }
    walk.connect(model, entry, in_component)
    if walk.actions.length() == loop_start {
      // A nonempty cycle is mandatory even when all fairness evidence is at entry.
      for action, next in model.transitions[entry] {
        if next >= 0 && membership[next] == id {
          walk.append(action, next)
          break
        }
      }
      walk.connect(model, entry, in_component)
    }
    return {
      witness: Some({
        states: walk.states,
        actions: walk.actions,
        loop_start: Some(loop_start),
      }),
      visited: reachable.order.length(),
      max_depth,
    }
  }
  { witness: None, visited: reachable.order.length(), max_depth, }
}
