///|
/// An SMT-LIB 2 command sequence over one `Context`.
///
/// Constants are declared automatically before the first command that
/// mentions them. `push` / `pop` track those declarations, so a constant
/// first used inside a popped scope is declared again when next needed.
pub struct Script {
  priv ctx : Context
  priv out : StringBuilder
  /// Indexed by constant; true while the solver has the declaration.
  priv declared : Array[Bool]
  priv log : Array[Int32]
  priv frames : Array[Int32]
}

///|
pub fn Script::new(ctx : Context, logic? : String) -> Script {
  let script = { ctx, out: StringBuilder(), declared: [], log: [], frames: [], }
  if logic is Some(logic) {
    script.command("set-logic", logic)
  }
  script
}

///|
fn Script::command(self : Script, name : String, argument : String) -> Unit {
  self.out.write_string("(")
  self.out.write_string(name)
  self.out.write_string(" ")
  self.out.write_string(argument)
  self.out.write_string(")\n")
}

///|
/// `(set-option :name value)`; `name` is written without the colon.
pub fn Script::set_option(self : Script, name : String, value : String) -> Unit {
  self.out.write_string("(set-option :")
  self.out.write_string(name)
  self.out.write_string(" ")
  self.out.write_string(value)
  self.out.write_string(")\n")
}

///|
/// Declare the constants among the nodes most recently visited.
fn Script::declare_visited(self : Script) -> Unit {
  let ctx = self.ctx
  for index in 0..<ctx.visited {
    let id = ctx.order[index]
    if ctx.op(id) != VAR {
      continue
    }
    let name = ctx.a(id)
    while self.declared.length() <= name {
      self.declared.push(false)
    }
    if !self.declared[name] {
      self.declared[name] = true
      self.log.push(name)
      self.out.write_string("(declare-const ")
      self.out.write_string(ctx.names[name])
      self.out.write_string(" ")
      ctx.sorts[id].write(self.out)
      self.out.write_string(")\n")
    }
  }
}

///|
/// Declare the constants of `term` now, for example before a `push`.
pub fn Script::declare_constants(self : Script, term : Term) -> Unit {
  self.ctx.visit([term])
  self.declare_visited()
}

///|
/// `(define-fun name () sort definition)`: fix a declared constant to a term
/// instead of declaring it, for example to supply runtime inputs. It must
/// precede every other use of the constant in the solver's current scope.
pub fn Script::define_constant(
  self : Script,
  constant : Term,
  definition : Term,
) -> Unit raise SmtError {
  let ctx = self.ctx
  guard ctx.op(constant.0) == VAR else {
    raise Unsupported("Only a declared constant can be defined")
  }
  guard ctx.sorts[definition.0] == ctx.sorts[constant.0] else {
    raise mismatch("define-fun", ctx.sorts[definition.0])
  }
  let name = ctx.a(constant.0)
  while self.declared.length() <= name {
    self.declared.push(false)
  }
  guard !self.declared[name] else {
    raise Unsupported(ctx.names[name] + " is already declared in this scope")
  }
  ctx.visit([definition])
  self.declare_visited()
  guard !self.declared[name] else {
    raise Unsupported(ctx.names[name] + " cannot be defined by itself")
  }
  self.declared[name] = true
  self.log.push(name)
  self.out.write_string("(define-fun ")
  self.out.write_string(ctx.names[name])
  self.out.write_string(" () ")
  ctx.sorts[constant.0].write(self.out)
  self.out.write_string(" ")
  ctx.write_visited(self.out, definition.0)
  self.out.write_string(")\n")
}

///|
/// `(assert term)`; `term` must be Boolean.
pub fn Script::assert_term(self : Script, term : Term) -> Unit raise SmtError {
  let ctx = self.ctx
  guard ctx.sorts[term.0] == Bool else {
    raise mismatch("assert", ctx.sorts[term.0])
  }
  ctx.visit([term])
  self.declare_visited()
  self.out.write_string("(assert ")
  ctx.write_visited(self.out, term.0)
  self.out.write_string(")\n")
}

///|
pub fn Script::check_sat(self : Script) -> Unit {
  self.out.write_string("(check-sat)\n")
}

///|
pub fn Script::push(self : Script) -> Unit {
  self.frames.push(self.log.length())
  self.out.write_string("(push 1)\n")
}

///|
pub fn Script::pop(self : Script) -> Unit raise SmtError {
  guard self.frames.pop() is Some(size) else {
    raise Unsupported("pop without a matching push")
  }
  while self.log.length() > size {
    self.declared[self.log.unsafe_pop()] = false
  }
  self.out.write_string("(pop 1)\n")
}

///|
/// `(get-value (t1 t2 ...))`. Decode the answer with `parse_values`, passing
/// the same terms.
pub fn Script::get_value(self : Script, terms : ArrayView[Term]) -> Unit {
  let ctx = self.ctx
  ctx.visit(terms)
  self.declare_visited()
  self.out.write_string("(get-value (")
  for index, term in terms {
    if index > 0 {
      self.out.write_string(" ")
    }
    // One traversal per term keeps `let` bindings local to that term.
    ctx.visit([term])
    ctx.write_visited(self.out, term.0)
  }
  self.out.write_string("))\n")
}

///|
pub fn Script::get_model(self : Script) -> Unit {
  self.out.write_string("(get-model)\n")
}

///|
/// `(echo "text")`, useful as an end marker when reading solver output.
pub fn Script::echo(self : Script, text : String) -> Unit {
  self.out.write_string("(echo ")
  write_string_literal(self.out, text)
  self.out.write_string(")\n")
}

///|
pub fn Script::exit(self : Script) -> Unit {
  self.out.write_string("(exit)\n")
}

///|
/// Append text verbatim, for commands this builder does not model.
pub fn Script::raw(self : Script, text : String) -> Unit {
  self.out.write_string(text)
}

///|
/// Everything written so far.
pub fn Script::to_string(self : Script) -> String {
  self.out.to_string()
}

///|
/// Return the pending text and clear it, keeping declaration tracking. An
/// incremental session sends each chunk exactly once this way.
pub fn Script::take(self : Script) -> String {
  let text = self.out.to_string()
  self.out.reset()
  text
}
