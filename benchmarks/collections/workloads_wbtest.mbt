///|
enum Output {
  Values(Array[Int])
  Count(Int)
} derive(Eq, Debug)

///|
struct Variant {
  name : String
  run : () -> Output
}

///|
struct Scenario {
  name : String
  variants : Array[Variant]
  expected : Output
}

///|
/// Fisher-Yates with a fixed xorshift seed. Generation is outside timing.
fn shuffled(size : Int) -> Array[Int] {
  let values = Array::makei(size, i => i)
  let mut state = 20260914U
  for i = size - 1; i > 0; i = i - 1 {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    let j = (state % (i + 1).reinterpret_as_uint()).reinterpret_as_int()
    let value = values[i]
    values[i] = values[j]
    values[j] = value
  }
  values
}

///|
fn veri_stack(values : Array[Int]) -> Output {
  let mut state : @stack.Stack[Int] = @stack.empty()
  for value in values {
    state = @stack.push(state, value)
  }
  let result = []
  while @stack.pop(state) is Some((value, rest)) {
    result.push(value)
    state = rest
  }
  Values(result)
}

///|
fn core_list_stack(values : Array[Int]) -> Output {
  let mut state : @core_list.List[Int] = @core_list.empty()
  for value in values {
    state = @core_list.cons(value, state)
  }
  let result = []
  while state is More(value, tail~) {
    result.push(value)
    state = tail
  }
  Values(result)
}

///|
fn array_stack(values : Array[Int]) -> Output {
  let state : Array[Int] = []
  for value in values {
    state.push(value)
  }
  let result = []
  while state.pop() is Some(value) {
    result.push(value)
  }
  Values(result)
}

///|
fn make_queue(values : Array[Int]) -> @queue.Queue[Int] {
  let mut state = @queue.empty()
  for value in values {
    state = @queue.push(state, value)
  }
  state
}

///|
fn veri_queue(values : Array[Int]) -> Output {
  let mut state = make_queue(values)
  let result = []
  while @queue.pop(state) is Some((value, rest)) {
    result.push(value)
    state = rest
  }
  Values(result)
}

///|
fn core_queue(values : Array[Int]) -> Output {
  let state : @core_queue.Queue[Int] = @core_queue.Queue([])
  for value in values {
    state.push(value)
  }
  let result = []
  while state.pop() is Some(value) {
    result.push(value)
  }
  Values(result)
}

///|
fn veri_pqueue(values : Array[Int]) -> Output {
  let mut state = @pqueue.empty()
  for value in values {
    state = @pqueue.push(state, value)
  }
  let result = []
  while @pqueue.pop(state) is Some((value, rest)) {
    result.push(value)
    state = rest
  }
  Values(result)
}

///|
fn core_pqueue(values : Array[Int]) -> Output {
  let state : @core_pqueue.PriorityQueue[@cmp.Reverse[Int]] = @core_pqueue.PriorityQueue([],
  )
  for value in values {
    state.push(@cmp.Reverse(value))
  }
  let result = []
  while state.pop() is Some(value) {
    result.push(value.0)
  }
  Values(result)
}

///|
fn core_immut_pqueue(values : Array[Int]) -> Output {
  let mut state : @core_immut_pqueue.PriorityQueue[@cmp.Reverse[Int]] = @core_immut_pqueue.PriorityQueue([],
  )
  for value in values {
    state = state.push(@cmp.Reverse(value))
  }
  let result = []
  while state.peek() is Some(value) {
    result.push(value.0)
    state = state.pop().unwrap()
  }
  Values(result)
}

///|
fn veri_search(values : Array[Int], queries : Array[Int]) -> Output {
  let mut state = @search.empty()
  for value in values {
    state = @search.insert(state, value)
  }
  let mut found = 0
  for value in queries {
    if @search.contains(state, value) {
      found = found + 1
    }
  }
  Count(found)
}

///|
fn core_search(values : Array[Int], queries : Array[Int]) -> Output {
  let mut state : @core_set.SortedSet[Int] = @core_set.new()
  for value in values {
    state = state.add(value)
  }
  let mut found = 0
  for value in queries {
    if state.contains(value) {
      found = found + 1
    }
  }
  Count(found)
}

///|
fn balanced(start : Int, stop : Int) -> @tree.Tree[Int] {
  if start >= stop {
    @tree.empty()
  } else {
    let middle = start + (stop - start) / 2
    @tree.node(balanced(start, middle), middle, balanced(middle + 1, stop))
  }
}

///|
fn scenarios(size : Int) -> Array[Scenario] {
  let values = shuffled(size)
  let ordered = Array::makei(size, i => i)
  let left = @linked.from_array(values)
  let right = @linked.from_array(values)
  let core_left = @core_list.List(values)
  let core_right = @core_list.List(values)
  let queue = make_queue(values)
  let core_fifo = @core_queue.Queue(values)
  let cases : Array[Scenario] = [
    {
      name: "list/reverse-to-array",
      expected: Values(values.rev()),
      variants: [
        {
          name: "veri",
          run: () => Values(@linked.to_array(@linked.reverse(left))),
        },
        { name: "core-list", run: () => Values(core_left.rev().to_array()), },
      ],
    },
    {
      name: "list/append-to-array",
      expected: Values(values + values),
      variants: [
        {
          name: "veri",
          run: () => Values(@linked.to_array(@linked.append(left, right))),
        },
        {
          name: "core-list",
          run: () => Values(core_left.concat(core_right).to_array()),
        },
      ],
    },
    {
      name: "list/length",
      expected: Count(size),
      variants: [
        { name: "veri", run: () => Count(@linked.length(left)), },
        { name: "core-list", run: () => Count(core_left.length()), },
      ],
    },
    {
      name: "stack/build-drain",
      expected: Values(values.rev()),
      variants: [
        { name: "veri", run: () => veri_stack(values), },
        { name: "core-list", run: () => core_list_stack(values), },
        { name: "core-array", run: () => array_stack(values), },
      ],
    },
    {
      name: "queue/build-drain",
      expected: Values(values),
      variants: [
        { name: "veri", run: () => veri_queue(values), },
        { name: "core-queue", run: () => core_queue(values), },
      ],
    },
    {
      name: "queue/repeated-peek",
      expected: Count(size * values.get(0).unwrap_or(0)),
      variants: [
        {
          name: "veri",
          run: () => {
            let mut sum = 0
            for _ in 0..<size {
              sum = sum + @queue.peek(queue).unwrap()
            }
            Count(sum)
          },
        },
        {
          name: "core-queue",
          run: () => {
            let mut sum = 0
            for _ in 0..<size {
              sum = sum + core_fifo.peek().unwrap()
            }
            Count(sum)
          },
        },
      ],
    },
  ]
  let queries = values + ordered.map(i => -i - 1)
  for (order, input) in [("shuffled", values), ("ascending", ordered)] {
    // Keep duplicates, so a set cannot accidentally pass as a priority queue.
    let duplicates = input.map(i => i / 2)
    let sorted = duplicates.copy()
    sorted.sort()
    cases.push({
      name: "pqueue/build-drain-\{order}",
      expected: Values(sorted),
      variants: [
        { name: "veri", run: () => veri_pqueue(duplicates), },
        { name: "core-immut-pqueue", run: () => core_immut_pqueue(duplicates), },
        { name: "core-pqueue", run: () => core_pqueue(duplicates), },
      ],
    })
    cases.push({
      name: "bst/build-find-\{order}",
      expected: Count(size),
      variants: [
        { name: "veri", run: () => veri_search(input, queries), },
        {
          name: "core-immut-sorted-set",
          run: () => core_search(input, queries),
        },
      ],
    })
  }
  let core_ordered = @core_set.SortedSet(ordered)
  let mut skewed = @tree.empty()
  for value in ordered {
    skewed = @tree.node(skewed, value, @tree.empty())
  }
  for
    (shape, input) in [("balanced", balanced(0, size)), ("left-skewed", skewed)] {
    cases.push({
      name: "tree/inorder-to-array-\{shape}",
      expected: Values(ordered),
      variants: [
        {
          name: "veri",
          run: () => Values(@linked.to_array(@tree.inorder(input))),
        },
        {
          name: "core-immut-sorted-set",
          run: () => Values(core_ordered.to_array()),
        },
      ],
    })
  }
  cases
}
