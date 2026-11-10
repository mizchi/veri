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
fn join_bits(low : Int32, high : Int32) -> UInt64 {
  low.reinterpret_as_uint().to_uint64() |
  (high.reinterpret_as_uint().to_uint64() << 32)
}

///|
/// Collect the subgraph below `roots` into `self.order`, children first, and
/// count in `self.refs` how often each node is used inside that subgraph.
fn Context::visit(self : Context, roots : ArrayView[Term]) -> Unit {
  let count = self.ops.length()
  while self.marks.length() < count {
    self.marks.push(0)
    self.refs.push(0)
  }
  self.generation += 1
  let generation = self.generation
  let order = self.order
  let stack = self.stack
  order.clear()
  stack.clear()
  for root in roots {
    self.discover(root.id, generation)
  }
  while stack.pop() is Some(id) {
    order.push(id)
    let children = arity[self.ops[id]]
    if children > 0 {
      self.discover(self.arg0[id], generation)
      if children > 1 {
        self.discover(self.arg1[id], generation)
        if children > 2 {
          self.discover(self.arg2[id], generation)
        }
      }
    }
  }
  // Ids increase from children to parents, so sorting is a topological order.
  order.sort()
}

///|
fn Context::discover(self : Context, id : Int32, generation : Int32) -> Unit {
  if self.marks[id] == generation {
    self.refs[id] += 1
  } else {
    self.marks[id] = generation
    self.refs[id] = 1
    self.stack.push(id)
  }
}

///|
/// Whether a visited node is printed once and then referred to by name.
fn Context::shared(self : Context, id : Int32) -> Bool {
  self.refs[id] > 1 && self.ops[id] > LAST_LEAF
}

///|
fn Context::write_leaf(self : Context, out : StringBuilder, id : Int32) -> Unit {
  let a = self.arg0[id]
  match self.ops[id] {
    VAR => out.write_string(self.names[a])
    TRUE => out.write_string("true")
    FALSE => out.write_string("false")
    INT_SMALL =>
      if a < 0 {
        out.write_string("(- ")
        write_int(out, -a)
        out.write_char(')')
      } else {
        write_int(out, a)
      }
    INT_BIG => write_integer(out, self.bigs[a])
    BV_LIT => {
      let width = self.sorts[id].width()
      write_bits(out, width, join_bits(a, self.arg1[id]))
    }
    STR_LIT => write_string_literal(out, self.strings[a])
    F32_LIT => write_f32(out, a.reinterpret_as_uint())
    _ => write_f64(out, join_bits(a, self.arg1[id]))
  }
}

///|
/// Write a leaf, or `(head` and schedule the operands and the closing paren.
fn Context::open(self : Context, out : StringBuilder, id : Int32) -> Unit {
  let op = self.ops[id]
  if op <= LAST_LEAF {
    self.write_leaf(out, id)
    return
  }
  let stack = self.stack
  out.write_char('(')
  stack.push(-1)
  match op {
    AND | OR | INT_ADD | INT_MUL | STR_CONCAT => {
      // These are n-ary in SMT-LIB: print an unshared left spine flat.
      out.write_string(heads[op])
      let mut current = id
      while true {
        stack.push(self.arg1[current])
        let left = self.arg0[current]
        if self.ops[left] == op && self.refs[left] < 2 {
          current = left
        } else {
          stack.push(left)
          break
        }
      }
      return
    }
    BV_EXTRACT => {
      out.write_string("(_ extract ")
      write_int(out, self.arg1[id])
      out.write_char(' ')
      write_int(out, self.arg2[id])
      out.write_char(')')
    }
    BV_ZERO_EXTEND => {
      out.write_string("(_ zero_extend ")
      write_int(out, self.arg1[id])
      out.write_char(')')
    }
    BV_SIGN_EXTEND => {
      out.write_string("(_ sign_extend ")
      write_int(out, self.arg1[id])
      out.write_char(')')
    }
    INT_TO_BV => {
      out.write_string("(_ int2bv ")
      write_int(out, self.arg1[id])
      out.write_char(')')
    }
    CONST_ARRAY => {
      out.write_string("(as const ")
      self.sorts[id].write(out)
      out.write_char(')')
    }
    FP_FROM_BITS =>
      out.write_string(
        if self.sorts[id] == Float32 {
          "(_ to_fp 8 24)"
        } else {
          "(_ to_fp 11 53)"
        },
      )
    FP_CONVERT =>
      out.write_string(
        if self.sorts[id] == Float32 {
          "(_ to_fp 8 24) RNE"
        } else {
          "(_ to_fp 11 53) RNE"
        },
      )
    _ => out.write_string(heads[op])
  }
  let children = arity[op]
  if children > 2 {
    stack.push(self.arg2[id])
  }
  if children > 1 {
    stack.push(self.arg1[id])
  }
  stack.push(self.arg0[id])
}

///|
/// Print one visited node as an expression, naming shared operands.
fn Context::emit(self : Context, out : StringBuilder, top : Int32) -> Unit {
  let stack = self.stack
  stack.clear()
  self.open(out, top)
  while stack.pop() is Some(item) {
    if item < 0 {
      out.write_char(')')
    } else {
      out.write_char(' ')
      if self.shared(item) {
        out.write_string("$t")
        write_int(out, item)
      } else {
        self.open(out, item)
      }
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
  for index in 0..<self.order.length() {
    let id = self.order[index]
    if id != root && self.shared(id) {
      out.write_string("(let (($t")
      write_int(out, id)
      out.write_char(' ')
      self.emit(out, id)
      out.write_string(")) ")
      bindings += 1
    }
  }
  self.emit(out, root)
  for _ in 0..<bindings {
    out.write_char(')')
  }
}

///|
/// Append the SMT-LIB 2 text of `term`.
pub fn Context::write(self : Context, out : StringBuilder, term : Term) -> Unit {
  self.visit([term])
  self.write_visited(out, term.id)
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
  self.order.length()
}

///|
/// The declared constants `term` mentions, in declaration order.
pub fn Context::free_constants(self : Context, term : Term) -> Array[Term] {
  self.visit([term])
  let result = []
  for id in self.order {
    if self.ops[id] == VAR {
      result.push({ id, })
    }
  }
  result
}
