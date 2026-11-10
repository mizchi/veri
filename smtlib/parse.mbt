///|
/// An S-expression as printed by a solver. Atoms are views into the input,
/// so tokenizing allocates no strings; quoted symbols lose their bars.
#derive(Debug)
pub(all) enum Sexp {
  Atom(StringView)
  Str(String)
  List(Array[Sexp])
}

///|
pub extend Sexp with @debug.Debug::{to_repr}

///|
fn is_space(unit : Int32) -> Bool {
  unit == ' ' || unit == '\n' || unit == '\r' || unit == '\t'
}

///|
fn hex_digit(unit : Int32) -> Int32 {
  if unit >= '0' && unit <= '9' {
    unit - '0'
  } else if unit >= 'a' && unit <= 'f' {
    unit - 'a' + 10
  } else if unit >= 'A' && unit <= 'F' {
    unit - 'A' + 10
  } else {
    -1
  }
}

///|
fn write_code_point(out : StringBuilder, code : Int32) -> Unit raise SmtError {
  guard code <= 0x2ffff && !(code >= 0xd800 && code <= 0xdfff) else {
    raise Unsupported("String character outside the supported alphabet")
  }
  out.write_char(code.unsafe_to_char())
}

///|
/// Read a string literal starting after its opening quote. Returns the
/// content and the offset after the closing quote. `""` is a quote, and
/// `\u{X}` / `\uXXXX` are the SMT-LIB 2.6 character escapes.
fn read_string(input : String, start : Int32) -> (String, Int32) raise SmtError {
  let length = input.length()
  let out = StringBuilder()
  let mut run = start
  let mut index = start
  while index < length {
    let unit = input.unsafe_get(index).to_int()
    if unit == '"' {
      out.write_substring(input, run, index - run)
      if index + 1 < length && input.unsafe_get(index + 1).to_int() == '"' {
        out.write_char('"')
        index += 2
        run = index
        continue
      }
      return (out.to_string(), index + 1)
    }
    if unit == '\\' &&
      index + 1 < length &&
      input.unsafe_get(index + 1).to_int() == 'u' {
      // An escape only when well formed; otherwise the backslash is literal.
      let mut cursor = index + 2
      let mut code = 0
      let mut digits = 0
      let braced = cursor < length && input.unsafe_get(cursor).to_int() == '{'
      if braced {
        cursor += 1
      }
      while cursor < length && digits < 5 {
        let digit = hex_digit(input.unsafe_get(cursor).to_int())
        if digit < 0 || (!braced && digits == 4) {
          break
        }
        code = code * 16 + digit
        digits += 1
        cursor += 1
      }
      let closed = if braced {
        digits >= 1 &&
        cursor < length &&
        input.unsafe_get(cursor).to_int() == '}'
      } else {
        digits == 4
      }
      if closed {
        out.write_substring(input, run, index - run)
        write_code_point(out, code)
        index = if braced { cursor + 1 } else { cursor }
        run = index
        continue
      }
    }
    index += 1
  }
  raise Malformed("Unterminated string literal")
}

///|
/// Parse every top-level S-expression in `input`. Comments run from `;` to
/// the end of the line. Nesting uses an explicit stack, so depth is bounded
/// by memory rather than by the call stack.
pub fn parse_sexps(input : String) -> Array[Sexp] raise SmtError {
  let length = input.length()
  let top : Array[Sexp] = []
  let open : Array[Array[Sexp]] = []
  let mut current = top
  let mut index = 0
  while index < length {
    let unit = input.unsafe_get(index).to_int()
    if is_space(unit) {
      index += 1
    } else if unit == '(' {
      open.push(current)
      current = []
      index += 1
    } else if unit == ')' {
      guard open.pop() is Some(parent) else {
        raise Malformed("Unbalanced closing parenthesis")
      }
      parent.push(List(current))
      current = parent
      index += 1
    } else if unit == ';' {
      while index < length && input.unsafe_get(index).to_int() != '\n' {
        index += 1
      }
    } else if unit == '"' {
      let (text, next) = read_string(input, index + 1)
      current.push(Str(text))
      index = next
    } else if unit == '|' {
      let start = index + 1
      index = start
      while index < length && input.unsafe_get(index).to_int() != '|' {
        index += 1
      }
      guard index < length else {
        raise Malformed("Unterminated quoted symbol")
      }
      current.push(Atom(input.exact_view(start~, end=index)))
      index += 1
    } else {
      let start = index
      while index < length {
        let unit = input.unsafe_get(index).to_int()
        if is_space(unit) ||
          unit == '(' ||
          unit == ')' ||
          unit == '"' ||
          unit == ';' {
          break
        }
        index += 1
      }
      current.push(Atom(input.exact_view(start~, end=index)))
    }
  }
  guard open.is_empty() else {
    raise Malformed("Unbalanced opening parenthesis")
  }
  top
}

///|
fn parse_digits(text : StringView) -> Int32 raise SmtError {
  guard text.length() >= 1 && text.length() <= 9 else {
    raise Malformed("Expected a small numeral: \{text}")
  }
  let mut value = 0
  for index in 0..<text.length() {
    let unit = text.unsafe_get(index).to_int()
    guard unit >= '0' && unit <= '9' else {
      raise Malformed("Expected a numeral: \{text}")
    }
    value = value * 10 + (unit - '0')
  }
  value
}

///|
fn parse_numeral(text : StringView) -> @bigint.BigInt raise SmtError {
  guard text.length() >= 1 else { raise Malformed("Expected a numeral") }
  // Machine arithmetic covers the common case without a big-integer parse.
  if text.length() <= 9 {
    return @bigint.BigInt::from_int(parse_digits(text))
  }
  for index in 0..<text.length() {
    let unit = text.unsafe_get(index).to_int()
    guard unit >= '0' && unit <= '9' else {
      raise Malformed("Expected a numeral: \{text}")
    }
  }
  @bigint.BigInt::from_string(text.to_owned())
}

///|
/// Decode `#x..` / `#b..` and return the bits with the literal's width.
fn parse_bits(text : StringView) -> (Int32, UInt64) raise SmtError {
  guard text.length() >= 3 && text.unsafe_get(0).to_int() == '#' else {
    raise Malformed("Expected a bitvector literal: \{text}")
  }
  let kind = text.unsafe_get(1).to_int()
  let digits = text.length() - 2
  let mut bits = 0UL
  if kind == 'x' {
    guard digits <= 16 else {
      raise Unsupported("Bitvector wider than 64 bits")
    }
    for index in 2..<text.length() {
      let digit = hex_digit(text.unsafe_get(index).to_int())
      guard digit >= 0 else { raise Malformed("Invalid hex literal: \{text}") }
      bits = (bits << 4) | digit.to_uint64()
    }
    (digits * 4, bits)
  } else if kind == 'b' {
    guard digits <= 64 else {
      raise Unsupported("Bitvector wider than 64 bits")
    }
    for index in 2..<text.length() {
      let unit = text.unsafe_get(index).to_int()
      guard unit == '0' || unit == '1' else {
        raise Malformed("Invalid binary literal: \{text}")
      }
      bits = (bits << 1) | (unit - '0').to_uint64()
    }
    (digits, bits)
  } else {
    raise Malformed("Expected a bitvector literal: \{text}")
  }
}

///|
/// Read a sort as solvers print it.
pub fn parse_sort(sexp : Sexp) -> Sort raise SmtError {
  match sexp {
    Atom("Bool") => Bool
    Atom("Int") => Int
    Atom("String") => String
    Atom("Float32") => Float32
    Atom("Float64") => Float64
    List([Atom("_"), Atom("BitVec"), Atom(width)]) => {
      let width = parse_digits(width)
      check_width(width)
      BitVec(width)
    }
    List([Atom("_"), Atom("FloatingPoint"), Atom("8"), Atom("24")]) => Float32
    List([Atom("_"), Atom("FloatingPoint"), Atom("11"), Atom("53")]) => Float64
    List([Atom("Array"), index, element]) =>
      Array(parse_sort(index), parse_sort(element))
    _ => raise Unsupported("Unsupported sort in solver output")
  }
}

///|
fn float_special(name : StringView, single : Bool) -> Value raise SmtError {
  let (negative, infinite) = match name {
    "NaN" => return if single { F32(NAN32) } else { F64(NAN64) }
    "+zero" => (false, false)
    "-zero" => (true, false)
    "+oo" => (false, true)
    "-oo" => (true, true)
    _ => raise Malformed("Unknown floating-point constant: \{name}")
  }
  if single {
    F32(
      (if negative { 0x8000_0000U } else { 0U }) |
      (if infinite { 0x7f80_0000U } else { 0U }),
    )
  } else {
    F64(
      (if negative { 0x8000_0000_0000_0000UL } else { 0UL }) |
      (if infinite { 0x7ff0_0000_0000_0000UL } else { 0UL }),
    )
  }
}

///|
/// Decode a value term of the expected sort, as printed by `get-value` or
/// `get-model`: literals, `(- n)`, `(_ bvN w)`, `(fp s e m)` and the named
/// floating-point constants, and arrays built from `as const` and `store`.
pub fn decode_value(sexp : Sexp, sort : Sort) -> Value raise SmtError {
  match (sort, sexp) {
    (Bool, Atom("true")) => Boolean(true)
    (Bool, Atom("false")) => Boolean(false)
    (Int, Atom(digits)) => Integer(parse_numeral(digits))
    (Int, List([Atom("-"), Atom(digits)])) => Integer(-parse_numeral(digits))
    (BitVec(width), Atom(literal)) => {
      let (found, bits) = parse_bits(literal)
      guard found == width else {
        raise Malformed("Expected \{width} bits, found \{found}")
      }
      Bits(width, bits)
    }
    (BitVec(width), List([Atom("_"), Atom(numeral), Atom(found)])) => {
      guard numeral.has_prefix("bv") && parse_digits(found) == width else {
        raise Malformed("Expected a \{width}-bit literal")
      }
      let value = parse_numeral(
        numeral.exact_view(start=2, end=numeral.length()),
      )
      guard value.bit_length() <= width else {
        raise Malformed("Bitvector literal exceeds \{width} bits")
      }
      Bits(width, value.to_uint64())
    }
    (String, Str(text)) => Value::text(text)
    (Float32, List([Atom("fp"), Atom(sign), Atom(exponent), Atom(fraction)])) => {
      let (sign_width, sign) = parse_bits(sign)
      let (exponent_width, exponent) = parse_bits(exponent)
      let (fraction_width, fraction) = parse_bits(fraction)
      guard sign_width == 1 && exponent_width == 8 && fraction_width == 23 else {
        raise Malformed("Expected a binary32 literal")
      }
      F32(canonical32(((sign << 31) | (exponent << 23) | fraction).to_uint()))
    }
    (Float64, List([Atom("fp"), Atom(sign), Atom(exponent), Atom(fraction)])) => {
      let (sign_width, sign) = parse_bits(sign)
      let (exponent_width, exponent) = parse_bits(exponent)
      let (fraction_width, fraction) = parse_bits(fraction)
      guard sign_width == 1 && exponent_width == 11 && fraction_width == 52 else {
        raise Malformed("Expected a binary64 literal")
      }
      F64(canonical64((sign << 63) | (exponent << 52) | fraction))
    }
    (Float32, List([Atom("_"), Atom(name), Atom("8"), Atom("24")])) =>
      float_special(name, true)
    (Float64, List([Atom("_"), Atom(name), Atom("11"), Atom("53")])) =>
      float_special(name, false)
    (Array(index, element), _) => decode_array(sexp, index, element)
    _ => raise Malformed("Value does not have sort " + sort.to_smtlib())
  }
}

///|
/// A store chain is unwound iteratively: models of large arrays nest deeply.
fn decode_array(
  sexp : Sexp,
  index : Sort,
  element : Sort,
) -> Value raise SmtError {
  let writes : Array[(Sexp, Sexp)] = []
  let mut current = sexp
  while true {
    match current {
      List([Atom("store"), array, key, value]) => {
        writes.push((key, value))
        current = array
      }
      List([List([Atom("as"), Atom("const"), sort]), default]) => {
        guard parse_sort(sort) == Array(index, element) else {
          raise Malformed("Constant array of an unexpected sort")
        }
        let mut table = ArrayValue::constant(
          index,
          decode_value(default, element),
        )
        // The innermost store was applied first.
        for position = writes.length() - 1
            position >= 0
            position = position - 1 {
          let (key, value) = writes[position]
          table = table.store(
            decode_value(key, index),
            decode_value(value, element),
          )
        }
        return Table(table)
      }
      List([Atom("lambda"), List([List([Atom(name), sort])]), body]) => {
        guard parse_sort(sort) == index else {
          raise Malformed("Lambda over an unexpected index sort")
        }
        let mut table = decode_lambda(body, name, index, element)
        for position = writes.length() - 1
            position >= 0
            position = position - 1 {
          let (key, value) = writes[position]
          table = table.store(
            decode_value(key, index),
            decode_value(value, element),
          )
        }
        return Table(table)
      }
      _ =>
        raise Unsupported(
          "Array value is not built from const, store or a case-split lambda",
        )
    }
  }
  raise Malformed("Unreachable array decoding state")
}

///|
/// The value of a lambda body at `key`. Bodies are case splits: `ite` over
/// Boolean combinations of `(= x literal)`, with literal results.
fn lambda_at(
  body : Sexp,
  name : StringView,
  key : Value,
  index : Sort,
  element : Sort,
  enumerated : Bool,
) -> Value raise SmtError {
  let mut current = body
  while true {
    match current {
      List([Atom("ite"), condition, then, otherwise]) =>
        current = if lambda_test(condition, name, key, index) {
          then
        } else {
          otherwise
        }
      Atom(atom) if atom == name => {
        guard index == element else {
          raise Malformed("Lambda result of an unexpected sort")
        }
        // Returning the parameter is a case split only over an enumerated
        // domain; elsewhere no finite table represents it.
        guard enumerated else {
          raise Unsupported("Array lambda returns its parameter")
        }
        return key
      }
      List([Atom("not"), _])
      | List([Atom("="), _, _])
      | List([Atom("distinct"), _, _])
      | List([Atom("and"), ..])
      | List([Atom("or"), ..]) if element == Bool =>
        return Boolean(lambda_test(current, name, key, index))
      _ => return decode_value(current, element)
    }
  }
  raise Malformed("Unreachable lambda decoding state")
}

///|
fn lambda_operand(
  sexp : Sexp,
  name : StringView,
  key : Value,
  index : Sort,
) -> Value raise SmtError {
  match sexp {
    Atom(atom) if atom == name => key
    _ => decode_value(sexp, index)
  }
}

///|
fn lambda_test(
  condition : Sexp,
  name : StringView,
  key : Value,
  index : Sort,
) -> Bool raise SmtError {
  match condition {
    Atom("true") => true
    Atom("false") => false
    Atom(atom) if atom == name && index == Bool => key == Boolean(true)
    List([Atom("not"), inner]) => !lambda_test(inner, name, key, index)
    List([Atom("="), left, right]) =>
      lambda_operand(left, name, key, index) ==
      lambda_operand(right, name, key, index)
    List([Atom("distinct"), left, right]) =>
      lambda_operand(left, name, key, index) !=
      lambda_operand(right, name, key, index)
    List([Atom("and"), .. parts]) => {
      for part in parts {
        guard lambda_test(part, name, key, index) else { return false }
      }
      true
    }
    List([Atom("or"), .. parts]) => {
      for part in parts {
        if lambda_test(part, name, key, index) {
          return true
        }
      }
      false
    }
    _ => raise Unsupported("Lambda condition outside the case-split fragment")
  }
}

///|
/// Tabulate a case-split lambda. Its value can only change at the literals
/// it compares its parameter with, so those keys plus one key that occurs
/// nowhere in the body determine the whole function. Small finite index
/// sorts are enumerated instead.
fn decode_lambda(
  body : Sexp,
  name : StringView,
  index : Sort,
  element : Sort,
) -> ArrayValue raise SmtError {
  let keys : Array[Value] = []
  let enumerated = match index {
    Bool => true
    BitVec(width) => width <= 8
    _ => false
  }
  let other : Value = match index {
    Bool => {
      keys.push(Boolean(true))
      Boolean(false)
    }
    BitVec(width) if width <= 8 => {
      for bits in 1..<(1 << width) {
        keys.push(Bits(width, bits.to_uint64()))
      }
      Bits(width, 0UL)
    }
    _ => {
      // Every literal of the index sort that is compared with the parameter.
      let pending = [body]
      while pending.pop() is Some(sexp) {
        match sexp {
          List([Atom("=" | "distinct"), left, right]) =>
            for side in [left, right] {
              if !(side is Atom(atom) && atom == name) {
                let key = decode_value(side, index) catch { _ => continue }
                if !keys.contains(key) {
                  keys.push(key)
                }
              }
            }
          List([Atom("lambda" | "let" | "forall" | "exists"), ..]) =>
            // A nested binder would need its own scope.
            raise Unsupported("Nested binder in an array lambda")
          List(parts) =>
            for part in parts {
              pending.push(part)
            }
          _ => ()
        }
      }
      fresh_key(index, keys)
    }
  }
  let mut table = ArrayValue::constant(
    index,
    lambda_at(body, name, other, index, element, enumerated),
  )
  for key in keys {
    table = table.store(
      key,
      lambda_at(body, name, key, index, element, enumerated),
    )
  }
  table
}

///|
/// A value of `sort` different from all of `keys`.
fn fresh_key(sort : Sort, keys : Array[Value]) -> Value raise SmtError {
  match sort {
    Int => {
      let mut next = 0N
      for key in keys {
        if key is Integer(value) && value >= next {
          next = value + 1N
        }
      }
      Integer(next)
    }
    BitVec(width) => {
      let mut bits = 0UL
      while keys.contains(Bits(width, bits)) {
        bits += 1UL
      }
      Bits(width, bits)
    }
    String => {
      let mut longest = 0
      for key in keys {
        if key is Text(text) && text.length() > longest {
          longest = text.length()
        }
      }
      Text(String::make(longest + 1, '!'))
    }
    _ => raise Unsupported("Array lambda over index sort " + sort.to_smtlib())
  }
}

///|
/// Substitute `let` bindings, which Z3's printer introduces for long values.
/// `scope` is the stack of bindings in effect; inner bindings shadow outer.
fn expand_lets(
  sexp : Sexp,
  scope : Array[(StringView, Sexp)],
) -> Sexp raise SmtError {
  match sexp {
    Str(_) => sexp
    Atom(name) => {
      for position = scope.length() - 1; position >= 0; position = position - 1 {
        if scope[position].0 == name {
          return scope[position].1
        }
      }
      sexp
    }
    List([Atom("let"), List(bindings), body]) => {
      let size = scope.length()
      // Bindings of one `let` are parallel: none sees the others.
      let bound : Array[(StringView, Sexp)] = []
      for binding in bindings {
        guard binding is List([Atom(name), definition]) else {
          raise Malformed("Malformed let binding")
        }
        bound.push((name, expand_lets(definition, scope)))
      }
      scope.append(bound)
      let result = expand_lets(body, scope)
      scope.truncate(size)
      result
    }
    List(parts) => {
      let expanded : Array[Sexp] = []
      for part in parts {
        expanded.push(expand_lets(part, scope))
      }
      List(expanded)
    }
  }
}

///|
/// Parse solver output, expanding `let` only when the text contains one.
fn parse_answer(output : String) -> Array[Sexp] raise SmtError {
  let sexps = parse_sexps(output)
  guard output.contains("(let ") else { return sexps }
  let expanded : Array[Sexp] = []
  for sexp in sexps {
    expanded.push(expand_lets(sexp, []))
  }
  expanded
}

///|
/// Decode a `get-value` answer `((t1 v1) (t2 v2) ...)` for `terms`, in order.
pub fn Context::parse_values(
  self : Context,
  output : String,
  terms : ArrayView[Term],
) -> Array[Value] raise SmtError {
  guard parse_answer(output) is [List(pairs)] &&
    pairs.length() == terms.length() else {
    raise Malformed("Expected one value per requested term")
  }
  let values : Array[Value] = []
  for position, pair in pairs {
    guard pair is List([_, value]) else {
      raise Malformed("Expected a (term value) pair")
    }
    values.push(decode_value(value, self.sorts[terms[position].id]))
  }
  values
}

///|
/// Decode a `get-model` answer. Only nullary definitions of supported sorts
/// are read; auxiliary function definitions are rejected rather than ignored
/// so a partially understood model is never returned.
pub fn parse_model(output : String) -> Model raise SmtError {
  let model = Model::new()
  let definitions = match parse_answer(output) {
    [List([Atom("model"), .. definitions])] => definitions
    [List(definitions)] => definitions[:]
    _ => raise Malformed("Expected one model")
  }
  for definition in definitions {
    guard definition
      is List([Atom("define-fun"), Atom(name), List([]), sort, value]) else {
      raise Unsupported("Model entry is not a constant definition")
    }
    model.set(name.to_owned(), decode_value(value, parse_sort(sort)))
  }
  model
}
