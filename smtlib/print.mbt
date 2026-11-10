///|
/// Number of child terms per operator. Other argument slots hold indices.
let arity : FixedArray[Int32] = {
  let table = FixedArray::make(FP_CONVERT + 1, 2)
  for op in 0..<=LAST_LEAF {
    table[op] = 0
  }
  for
    op in [
      NOT,
      INT_NEG,
      INT_ABS,
      BV_NOT,
      BV_NEG,
      BV_EXTRACT,
      BV_ZERO_EXTEND,
      BV_SIGN_EXTEND,
      BV_TO_NAT,
      INT_TO_BV,
      CONST_ARRAY,
      STR_LEN,
      STR_TO_INT,
      STR_FROM_INT,
      FP_SQRT,
      FP_NEG,
      FP_ABS,
      FP_IS_NAN,
      FP_IS_INFINITE,
      FP_IS_ZERO,
      FP_FROM_BITS,
      FP_CONVERT,
    ] {
    table[op] = 1
  }
  for op in [ITE, STORE, STR_SUBSTR, STR_INDEX_OF, STR_REPLACE] {
    table[op] = 3
  }
  table
}

///|
/// Text between `(` and the first operand, for operators without indices.
let heads : FixedArray[String] = {
  let table = FixedArray::make(FP_CONVERT + 1, "")
  for
    entry in [
      (NOT, "not"),
      (AND, "and"),
      (OR, "or"),
      (XOR, "xor"),
      (IMPLIES, "=>"),
      (EQUAL, "="),
      (DISTINCT, "distinct"),
      (ITE, "ite"),
      (INT_ADD, "+"),
      (INT_SUB, "-"),
      (INT_MUL, "*"),
      (INT_NEG, "-"),
      (INT_DIV, "div"),
      (INT_MOD, "mod"),
      (INT_ABS, "abs"),
      (INT_LE, "<="),
      (INT_LT, "<"),
      (BV_ADD, "bvadd"),
      (BV_SUB, "bvsub"),
      (BV_MUL, "bvmul"),
      (BV_UDIV, "bvudiv"),
      (BV_UREM, "bvurem"),
      (BV_SDIV, "bvsdiv"),
      (BV_SREM, "bvsrem"),
      (BV_AND, "bvand"),
      (BV_OR, "bvor"),
      (BV_XOR, "bvxor"),
      (BV_NOT, "bvnot"),
      (BV_NEG, "bvneg"),
      (BV_SHL, "bvshl"),
      (BV_LSHR, "bvlshr"),
      (BV_ASHR, "bvashr"),
      (BV_ULT, "bvult"),
      (BV_ULE, "bvule"),
      (BV_SLT, "bvslt"),
      (BV_SLE, "bvsle"),
      (BV_CONCAT, "concat"),
      (BV_TO_NAT, "bv2nat"),
      (SELECT, "select"),
      (STORE, "store"),
      (STR_CONCAT, "str.++"),
      (STR_LEN, "str.len"),
      (STR_AT, "str.at"),
      (STR_SUBSTR, "str.substr"),
      (STR_CONTAINS, "str.contains"),
      (STR_PREFIX_OF, "str.prefixof"),
      (STR_SUFFIX_OF, "str.suffixof"),
      (STR_INDEX_OF, "str.indexof"),
      (STR_REPLACE, "str.replace"),
      (STR_TO_INT, "str.to_int"),
      (STR_FROM_INT, "str.from_int"),
      (STR_LT, "str.<"),
      (STR_LE, "str.<="),
      (FP_ADD, "fp.add RNE"),
      (FP_SUB, "fp.sub RNE"),
      (FP_MUL, "fp.mul RNE"),
      (FP_DIV, "fp.div RNE"),
      (FP_SQRT, "fp.sqrt RNE"),
      (FP_NEG, "fp.neg"),
      (FP_ABS, "fp.abs"),
      (FP_EQ, "fp.eq"),
      (FP_LT, "fp.lt"),
      (FP_LE, "fp.leq"),
      (FP_IS_NAN, "fp.isNaN"),
      (FP_IS_INFINITE, "fp.isInfinite"),
      (FP_IS_ZERO, "fp.isZero"),
    ] {
    table[entry.0] = entry.1
  }
  table
}

///|
/// `(` followed by the head: one append opens an application.
let opened : FixedArray[String] = FixedArray::makei(heads.length(), op => {
  "(" + heads[op]
})

///|
/// Make every scratch buffer large enough for the current arena.
fn Context::reserve(self : Context) -> Unit {
  let count = self.count
  if self.marks.length() < count {
    let capacity = self.sorts.length()
    // Stale stamps are harmless, so the buffers start over.
    self.marks = FixedArray::make(capacity, 0)
    self.refs = FixedArray::make(capacity, 0)
    self.order = FixedArray::make(capacity, 0)
    // Printing holds at most one entry per edge plus one closer per node.
    self.stack = FixedArray::make(capacity * 4 + 4, 0)
    self.generation = 0
  }
}

///|
/// Collect the subgraph below `roots` into `self.order[..self.visited]`,
/// children first, and count in `self.refs` how often each node is used
/// inside that subgraph.
fn Context::visit(self : Context, roots : ArrayView[Term]) -> Unit {
  self.reserve()
  self.generation += 1
  let generation = self.generation
  let nodes = self.nodes
  let marks = self.marks
  let refs = self.refs
  let order = self.order
  let stack = self.stack
  let mut top = 0
  let mut visited = 0
  let mut lowest = self.count
  let mut highest = -1
  for root in roots {
    let id = root.0
    if marks.unsafe_get(id) == generation {
      refs[id] += 1
    } else {
      marks[id] = generation
      refs[id] = 1
      stack[top] = id
      top += 1
    }
  }
  while top > 0 {
    top -= 1
    let id = stack.unsafe_get(top)
    order[visited] = id
    visited += 1
    if id < lowest {
      lowest = id
    }
    if id > highest {
      highest = id
    }
    let base = id * 4
    let children = arity.unsafe_get(nodes.unsafe_get(base))
    for slot in 1..<=children {
      let child = nodes.unsafe_get(base + slot)
      if marks.unsafe_get(child) == generation {
        refs[child] += 1
      } else {
        marks[child] = generation
        refs[child] = 1
        stack[top] = child
        top += 1
      }
    }
  }
  self.visited = visited
  // Ids increase from children to parents, so ascending ids are a
  // topological order. A dense subgraph is read off the stamps in one
  // sweep; a sparse one is sorted.
  if visited > 1 {
    if highest - lowest < visited * 4 {
      let mut next = 0
      for id in lowest..<=highest {
        if marks.unsafe_get(id) == generation {
          order[next] = id
          next += 1
        }
      }
    } else {
      let sorted = Array::makei(visited, index => order[index])
      sorted.sort()
      for index, id in sorted {
        order[index] = id
      }
    }
  }
}

///|
/// Whether a visited node is printed once and then referred to by name.
fn Context::shared(self : Context, id : Int32) -> Bool {
  self.refs.unsafe_get(id) > 1 && self.op(id) > LAST_LEAF
}

///|
fn Context::write_leaf(self : Context, out : StringBuilder, id : Int32) -> Unit {
  let a = self.a(id)
  match self.op(id) {
    VAR => out.write_string(self.names[a])
    TRUE => out.write_string("true")
    FALSE => out.write_string("false")
    INT_SMALL =>
      if a < 0 {
        out.write_string("(- ")
        write_int(out, -a)
        out.write_string(")")
      } else {
        write_int(out, a)
      }
    INT_BIG => write_integer(out, self.bigs[a])
    BV_LIT => write_bits(out, self.c(id), a, self.b(id))
    STR_LIT => write_string_literal(out, self.strings[a])
    F32_LIT => write_f32(out, a)
    _ => write_f64(out, a, self.b(id))
  }
}

///|
/// Write a leaf, or `(head` and schedule the operands and the closing
/// parenthesis on the work stack. Returns the new stack height.
fn Context::open(
  self : Context,
  out : StringBuilder,
  id : Int32,
  top : Int32,
) -> Int32 {
  let op = self.op(id)
  if op <= LAST_LEAF {
    self.write_leaf(out, id)
    return top
  }
  let stack = self.stack
  let mut top = top
  stack[top] = -1
  top += 1
  match op {
    AND | OR | INT_ADD | INT_MUL | STR_CONCAT => {
      // These are n-ary in SMT-LIB: print an unshared left spine flat.
      out.write_string("(")
      out.write_string(heads[op])
      let mut current = id
      while true {
        stack[top] = self.b(current)
        top += 1
        let left = self.a(current)
        if self.op(left) == op && self.refs.unsafe_get(left) < 2 {
          current = left
        } else {
          stack[top] = left
          top += 1
          break
        }
      }
      return top
    }
    BV_EXTRACT => {
      out.write_string("((_ extract ")
      write_int(out, self.b(id))
      out.write_string(" ")
      write_int(out, self.c(id))
      out.write_string(")")
    }
    BV_ZERO_EXTEND => {
      out.write_string("((_ zero_extend ")
      write_int(out, self.b(id))
      out.write_string(")")
    }
    BV_SIGN_EXTEND => {
      out.write_string("((_ sign_extend ")
      write_int(out, self.b(id))
      out.write_string(")")
    }
    INT_TO_BV => {
      out.write_string("((_ int2bv ")
      write_int(out, self.b(id))
      out.write_string(")")
    }
    CONST_ARRAY => {
      out.write_string("((as const ")
      self.sorts[id].write(out)
      out.write_string(")")
    }
    FP_FROM_BITS =>
      out.write_string(
        if self.sorts[id] == Float32 {
          "((_ to_fp 8 24)"
        } else {
          "((_ to_fp 11 53)"
        },
      )
    FP_CONVERT =>
      out.write_string(
        if self.sorts[id] == Float32 {
          "((_ to_fp 8 24) RNE"
        } else {
          "((_ to_fp 11 53) RNE"
        },
      )
    _ => out.write_string(opened[op])
  }
  let base = id * 4
  for slot = arity[op]; slot >= 1; slot = slot - 1 {
    stack[top] = self.nodes.unsafe_get(base + slot)
    top += 1
  }
  top
}

///|
/// Print one visited node as an expression, naming shared operands.
fn Context::emit(self : Context, out : StringBuilder, root : Int32) -> Unit {
  let stack = self.stack
  let mut top = self.open(out, root, 0)
  while top > 0 {
    top -= 1
    let item = stack.unsafe_get(top)
    if item < 0 {
      out.write_string(")")
    } else if self.shared(item) {
      out.write_string(" $t")
      write_int(out, item)
    } else {
      out.write_string(" ")
      top = self.open(out, item, top)
    }
  }
}

///|
/// Print the term most recently passed to `visit`.
///
/// A subterm used more than once is bound by `let` and printed a single
/// time, so the output is linear in the number of distinct subterms even
/// when the equivalent tree would be exponential.
fn Context::write_visited(
  self : Context,
  out : StringBuilder,
  root : Int32,
) -> Unit {
  let mut bindings = 0
  for index in 0..<self.visited {
    let id = self.order.unsafe_get(index)
    if id != root && self.shared(id) {
      out.write_string("(let (($t")
      write_int(out, id)
      out.write_string(" ")
      self.emit(out, id)
      out.write_string(")) ")
      bindings += 1
    }
  }
  self.emit(out, root)
  for _ in 0..<bindings {
    out.write_string(")")
  }
}

///|
/// Append the SMT-LIB 2 text of `term`.
pub fn Context::write(self : Context, out : StringBuilder, term : Term) -> Unit {
  self.visit([term])
  self.write_visited(out, term.0)
}

///|
/// The SMT-LIB 2 text of `term`, without declarations.
pub fn Context::to_smtlib(self : Context, term : Term) -> String {
  let out = StringBuilder()
  self.write(out, term)
  out.to_string()
}

///|
/// Number of distinct subterms of `term`, including itself.
pub fn Context::dag_size(self : Context, term : Term) -> Int32 {
  self.visit([term])
  self.visited
}

///|
/// The declared constants `term` mentions, in declaration order.
pub fn Context::free_constants(self : Context, term : Term) -> Array[Term] {
  self.visit([term])
  let result = []
  for index in 0..<self.visited {
    let id = self.order.unsafe_get(index)
    if self.op(id) == VAR {
      result.push(Term(id))
    }
  }
  result
}
