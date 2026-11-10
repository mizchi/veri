// Operators are small integers: literal bits, indices and pool positions live in
// the argument slots, so a node is five machine words, an operator comparison
// is an integer comparison, and dispatch compiles to a jump table.
// Leaves come first; `LAST_LEAF` separates them from applications.

///|
const VAR : Int32 = 0

///|
const TRUE : Int32 = 1

///|
const FALSE : Int32 = 2

///|
const INT_SMALL : Int32 = 3

///|
const INT_BIG : Int32 = 4

///|
const BV_LIT : Int32 = 5

///|
const STR_LIT : Int32 = 6

///|
const F32_LIT : Int32 = 7

///|
const F64_LIT : Int32 = 8

///|
const NOT : Int32 = 9

///|
const AND : Int32 = 10

///|
const OR : Int32 = 11

///|
const XOR : Int32 = 12

///|
const IMPLIES : Int32 = 13

///|
const EQUAL : Int32 = 14

///|
const DISTINCT : Int32 = 15

///|
const ITE : Int32 = 16

///|
const INT_ADD : Int32 = 17

///|
const INT_SUB : Int32 = 18

///|
const INT_MUL : Int32 = 19

///|
const INT_NEG : Int32 = 20

///|
const INT_DIV : Int32 = 21

///|
const INT_MOD : Int32 = 22

///|
const INT_ABS : Int32 = 23

///|
const INT_LE : Int32 = 24

///|
const INT_LT : Int32 = 25

///|
const BV_ADD : Int32 = 26

///|
const BV_SUB : Int32 = 27

///|
const BV_MUL : Int32 = 28

///|
const BV_UDIV : Int32 = 29

///|
const BV_UREM : Int32 = 30

///|
const BV_SDIV : Int32 = 31

///|
const BV_SREM : Int32 = 32

///|
const BV_AND : Int32 = 33

///|
const BV_OR : Int32 = 34

///|
const BV_XOR : Int32 = 35

///|
const BV_NOT : Int32 = 36

///|
const BV_NEG : Int32 = 37

///|
const BV_SHL : Int32 = 38

///|
const BV_LSHR : Int32 = 39

///|
const BV_ASHR : Int32 = 40

///|
const BV_ULT : Int32 = 41

///|
const BV_ULE : Int32 = 42

///|
const BV_SLT : Int32 = 43

///|
const BV_SLE : Int32 = 44

///|
const BV_CONCAT : Int32 = 45

///|
const BV_EXTRACT : Int32 = 46

///|
const BV_ZERO_EXTEND : Int32 = 47

///|
const BV_SIGN_EXTEND : Int32 = 48

///|
const BV_TO_NAT : Int32 = 49

///|
const INT_TO_BV : Int32 = 50

///|
const SELECT : Int32 = 51

///|
const STORE : Int32 = 52

///|
const CONST_ARRAY : Int32 = 53

///|
const STR_CONCAT : Int32 = 54

///|
const STR_LEN : Int32 = 55

///|
const STR_AT : Int32 = 56

///|
const STR_SUBSTR : Int32 = 57

///|
const STR_CONTAINS : Int32 = 58

///|
const STR_PREFIX_OF : Int32 = 59

///|
const STR_SUFFIX_OF : Int32 = 60

///|
const STR_INDEX_OF : Int32 = 61

///|
const STR_REPLACE : Int32 = 62

///|
const STR_TO_INT : Int32 = 63

///|
const STR_FROM_INT : Int32 = 64

///|
const STR_LT : Int32 = 65

///|
const STR_LE : Int32 = 66

///|
const FP_ADD : Int32 = 67

///|
const FP_SUB : Int32 = 68

///|
const FP_MUL : Int32 = 69

///|
const FP_DIV : Int32 = 70

///|
const FP_SQRT : Int32 = 71

///|
const FP_NEG : Int32 = 72

///|
const FP_ABS : Int32 = 73

///|
const FP_EQ : Int32 = 74

///|
const FP_LT : Int32 = 75

///|
const FP_LE : Int32 = 76

///|
const FP_IS_NAN : Int32 = 77

///|
const FP_IS_INFINITE : Int32 = 78

///|
const FP_IS_ZERO : Int32 = 79

///|
const FP_FROM_BITS : Int32 = 80

///|
const FP_CONVERT : Int32 = 81

///|
const LAST_LEAF : Int32 = 8

///|
/// A handle to a hash-consed term. Structurally equal terms built in the same
/// `Context` are the same handle, so `==` is a constant-time comparison.
/// A handle is only meaningful for the context that created it.
#derive(Eq, Hash, Debug)
pub struct Term {
  priv id : Int32
}

///|
pub extend Term with Eq::{not_equal, equal}

///|
pub extend Term with Hash::{hash, hash_combine}

///|
pub extend Term with @debug.Debug::{to_repr}

///|
/// An append-only term arena.
///
/// Children always have smaller ids than their parents, so the node order is
/// a topological order. Traversals use explicit stacks and generation stamps:
/// their cost is proportional to the visited subgraph, not to the arena, and
/// deep terms cannot overflow the call stack.
pub struct Context {
  priv ops : Array[Int32]
  priv arg0 : Array[Int32]
  priv arg1 : Array[Int32]
  priv arg2 : Array[Int32]
  priv sorts : Array[Sort]
  priv hashes : Array[Int32]
  /// Open addressing; a slot holds `id + 1`, and 0 marks an empty slot.
  priv mut table : FixedArray[Int32]
  priv names : Array[String]
  priv vars : Map[String, Int32]
  priv strings : Array[String]
  priv string_ids : Map[String, Int32]
  priv bigs : Array[@bigint.BigInt]
  priv big_ids : Map[@bigint.BigInt, Int32]
  // Traversal scratch, indexed by node id.
  priv marks : Array[Int32]
  priv refs : Array[Int32]
  priv mut generation : Int32
  priv order : Array[Int32]
  priv stack : Array[Int32]
  priv values : Array[Value]
}

///|
pub fn Context::new() -> Context {
  {
    ops: [],
    arg0: [],
    arg1: [],
    arg2: [],
    sorts: [],
    hashes: [],
    table: FixedArray::make(256, 0),
    names: [],
    vars: Map([]),
    strings: [],
    string_ids: Map([]),
    bigs: [],
    big_ids: Map([]),
    marks: [],
    refs: [],
    generation: 0,
    order: [],
    stack: [],
    values: [],
  }
}

///|
/// Number of distinct terms created so far.
pub fn Context::term_count(self : Context) -> Int32 {
  self.ops.length()
}

///|
pub fn Context::sort_of(self : Context, term : Term) -> Sort {
  self.sorts[term.id]
}

///|
fn mix(op : Int32, a : Int32, b : Int32, c : Int32) -> Int32 {
  let mut h = (op + 1) * 0x9e3779b1
  h = (h ^ a) * 0x85ebca6b
  h = (h ^ (h >> 15) ^ b) * 0xc2b2ae35
  h = (h ^ (h >> 13) ^ c) * 0x27d4eb2f
  h ^ (h >> 16)
}

///|
fn Context::grow(self : Context) -> Unit {
  let size = self.table.length() * 2
  let table = FixedArray::make(size, 0)
  let slot_mask = size - 1
  for id, hash in self.hashes {
    let mut slot = hash & slot_mask
    while table[slot] != 0 {
      slot = (slot + 1) & slot_mask
    }
    table[slot] = id + 1
  }
  self.table = table
}

///|
/// Return the existing node with this shape, or append it.
fn Context::intern(
  self : Context,
  op : Int32,
  a : Int32,
  b : Int32,
  c : Int32,
  sort : Sort,
) -> Term {
  let hash = mix(op, a, b, c)
  let slot_mask = self.table.length() - 1
  let mut slot = hash & slot_mask
  while true {
    let entry = self.table[slot]
    if entry == 0 {
      break
    }
    let id = entry - 1
    if self.hashes[id] == hash &&
      self.arg0[id] == a &&
      self.arg1[id] == b &&
      self.arg2[id] == c &&
      self.ops[id] == op &&
      self.sorts[id] == sort {
      return { id, }
    }
    slot = (slot + 1) & slot_mask
  }
  let id = self.ops.length()
  self.ops.push(op)
  self.arg0.push(a)
  self.arg1.push(b)
  self.arg2.push(c)
  self.sorts.push(sort)
  self.hashes.push(hash)
  self.table[slot] = id + 1
  // Keep the load factor at most one half.
  if (id + 1) * 2 > self.table.length() {
    self.grow()
  }
  { id, }
}

///|
fn mismatch(operation : String, found : Sort) -> SmtError {
  SortMismatch("\{operation} does not accept " + found.to_smtlib())
}

///|
fn valid_symbol_char(unit : Int32) -> Bool {
  (unit >= 'a' && unit <= 'z') ||
  (unit >= 'A' && unit <= 'Z') ||
  (unit >= '0' && unit <= '9') ||
  unit == '_' ||
  unit == '.' ||
  unit == '!' ||
  unit == '-' ||
  unit == '?' ||
  unit == '@' ||
  unit == '%'
}

///|
/// Constants use plain SMT-LIB simple symbols, so a name is printed verbatim
/// and read back from a model without quoting. Names beginning with `$` are
/// reserved for the bindings the printer generates.
fn check_name(name : String) -> Unit raise SmtError {
  guard !name.is_empty() && name.length() <= 255 else {
    raise Unsupported("Constant names must have 1 to 255 characters")
  }
  let first = name.unsafe_get(0).to_int()
  guard !(first >= '0' && first <= '9') && first != '.' && first != '@' else {
    raise Unsupported("Invalid constant name: " + name)
  }
  for unit in name.to_array() {
    guard valid_symbol_char(unit.to_int()) else {
      raise Unsupported("Invalid constant name: " + name)
    }
  }
  match name {
    "true"
    | "false"
    | "not"
    | "and"
    | "or"
    | "xor"
    | "ite"
    | "let"
    | "forall"
    | "exists"
    | "as"
    | "par"
    | "select"
    | "store"
    | "distinct"
    | "div"
    | "mod"
    | "abs"
    | "concat"
    | "fp"
    | "RNE"
    | "bv2nat"
    | "_"
    | "-" => raise Unsupported("Reserved constant name: " + name)
    _ => ()
  }
}

///|
fn check_sort(sort : Sort) -> Unit raise SmtError {
  match sort {
    BitVec(width) => check_width(width)
    Array(index, element) => {
      check_sort(index)
      check_sort(element)
    }
    _ => ()
  }
}

///|
/// Declare (or look up) the uninterpreted constant `name`. Declaring a name
/// again with the same sort returns the same term; another sort is an error.
pub fn Context::constant(
  self : Context,
  name : String,
  sort : Sort,
) -> Term raise SmtError {
  match self.vars.get(name) {
    Some(id) => {
      guard self.sorts[id] == sort else {
        raise SortMismatch(
          "\{name} is already declared as " + self.sorts[id].to_smtlib(),
        )
      }
      { id, }
    }
    None => {
      check_name(name)
      check_sort(sort)
      let term = self.intern(VAR, self.names.length(), -1, -1, sort)
      self.names.push(name)
      self.vars.set(name, term.id)
      term
    }
  }
}

///|
/// A declared constant together with the runtime type its values decode to.
pub struct Typed[T] {
  term : Term
  name : String
  priv decode : (Value) -> T?
}

///|
/// A constant whose sort is that of the runtime type `T`:
/// `let x : Typed[UInt] = ctx.typed("x")` declares `(_ BitVec 32)`.
pub fn[T : Encode] Context::typed(
  self : Context,
  name : String,
) -> Typed[T] raise SmtError {
  { term: self.constant(name, T::sort()), name, decode: T::from_value, }
}

///|
/// The declared constant named `name`, if any.
pub fn Context::lookup(self : Context, name : String) -> Term? {
  match self.vars.get(name) {
    Some(id) => Some({ id, })
    None => None
  }
}

///|
/// The name of a declared constant; `None` for any other term.
pub fn Context::name_of(self : Context, term : Term) -> String? {
  if self.ops[term.id] == VAR {
    Some(self.names[self.arg0[term.id]])
  } else {
    None
  }
}

// Literals

///|
pub fn Context::bool(self : Context, value : Bool) -> Term {
  self.intern(if value { TRUE } else { FALSE }, -1, -1, -1, Bool)
}

///|
pub fn Context::int(self : Context, value : Int32) -> Term {
  self.intern(INT_SMALL, value, -1, -1, Int)
}

///|
pub fn Context::integer(self : Context, value : @bigint.BigInt) -> Term {
  if value >= -0x4000_0000N && value <= 0x3fff_ffffN {
    return self.int(value.to_int())
  }
  let index = match self.big_ids.get(value) {
    Some(index) => index
    None => {
      let index = self.bigs.length()
      self.bigs.push(value)
      self.big_ids.set(value, index)
      index
    }
  }
  self.intern(INT_BIG, index, -1, -1, Int)
}

///|
fn Context::bits(self : Context, sort : Sort, bits : UInt64) -> Term {
  self.intern(
    BV_LIT,
    bits.to_uint().reinterpret_as_int(),
    (bits >> 32).to_uint().reinterpret_as_int(),
    -1,
    sort,
  )
}

///|
/// A bitvector literal; bits above `width` are discarded.
pub fn Context::bv(
  self : Context,
  width : Int32,
  bits : UInt64,
) -> Term raise SmtError {
  check_width(width)
  self.bits(BitVec(width), bits & mask(width))
}

///|
/// A string literal within the SMT alphabet (see `Value::text`).
pub fn Context::string(self : Context, value : String) -> Term raise SmtError {
  let index = match self.string_ids.get(value) {
    Some(index) => index
    None => {
      ignore(Value::text(value))
      let index = self.strings.length()
      self.strings.push(value)
      self.string_ids.set(value, index)
      index
    }
  }
  self.intern(STR_LIT, index, -1, -1, String)
}

///|
pub fn Context::float32(self : Context, value : Float) -> Term {
  self.intern(
    F32_LIT,
    float32_bits(value).reinterpret_as_int(),
    -1,
    -1,
    Float32,
  )
}

///|
pub fn Context::float64(self : Context, value : Double) -> Term {
  let bits = float64_bits(value)
  self.intern(
    F64_LIT,
    bits.to_uint().reinterpret_as_int(),
    (bits >> 32).to_uint().reinterpret_as_int(),
    -1,
    Float64,
  )
}

///|
/// The literal term for a concrete value. A table becomes a store chain over
/// a constant array, ordered by the printed form of its keys.
pub fn Context::value(self : Context, value : Value) -> Term raise SmtError {
  match value {
    Boolean(value) => self.bool(value)
    Integer(value) => self.integer(value)
    Bits(width, bits) => self.bv(width, bits)
    Text(value) => self.string(value)
    F32(bits) =>
      self.intern(
        F32_LIT,
        canonical32(bits).reinterpret_as_int(),
        -1,
        -1,
        Float32,
      )
    F64(bits) => {
      let bits = canonical64(bits)
      self.intern(
        F64_LIT,
        bits.to_uint().reinterpret_as_int(),
        (bits >> 32).to_uint().reinterpret_as_int(),
        -1,
        Float64,
      )
    }
    Table(table) => {
      let cells = table.entries
        .to_array()
        .map(cell => (cell.0.to_smtlib(), cell.0, cell.1))
      cells.sort_by_key(cell => cell.0)
      let mut term = self.const_array(table.index, self.value(table.default))
      for cell in cells {
        term = self.store(term, self.value(cell.1), self.value(cell.2))
      }
      term
    }
  }
}

///|
/// The literal for a runtime value: `ctx.literal(7U)` is `#x00000007`.
pub fn[T : Encode] Context::literal(
  self : Context,
  value : T,
) -> Term raise SmtError {
  self.value(T::to_value(value))
}
