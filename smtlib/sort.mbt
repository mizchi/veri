///|
/// The SMT-LIB 2 sorts that have a MoonBit runtime counterpart in this module.
/// Bitvector widths are limited to 1..=64 so a value fits one machine word.
#derive(Eq, Hash, Debug)
pub(all) enum Sort {
  Bool
  Int
  BitVec(Int32)
  Array(Sort, Sort)
  String
  Float32
  Float64
}

///|
pub extend Sort with Eq::{not_equal, equal}

///|
pub extend Sort with Hash::{hash, hash_combine}

///|
pub extend Sort with @debug.Debug::{to_repr}

///|
#derive(Debug)
pub(all) suberror SmtError {
  /// A term was built or evaluated with operands of the wrong sort.
  SortMismatch(String)
  /// A symbol, literal or width outside the supported fragment.
  Unsupported(String)
  /// Solver text that is not the expected S-expression or value.
  Malformed(String)
  /// SMT-LIB leaves the result open (integer division by zero) or the
  /// assignment has no value for a declared constant.
  Unspecified(String)
}

///|
pub extend SmtError with @debug.Debug::{to_repr}

///|
/// Largest supported bitvector width.
pub const MAX_WIDTH : Int32 = 64

///|
fn check_width(width : Int32) -> Unit raise SmtError {
  guard width >= 1 && width <= MAX_WIDTH else {
    raise Unsupported("Bitvector width \{width} is outside 1..=64")
  }
}

///|
/// All ones in the low `width` bits.
fn mask(width : Int32) -> UInt64 {
  if width >= 64 {
    0xffff_ffff_ffff_ffffUL
  } else {
    (1UL << width) - 1UL
  }
}

///|
pub fn Sort::write(self : Sort, out : StringBuilder) -> Unit {
  match self {
    Bool => out.write_string("Bool")
    Int => out.write_string("Int")
    String => out.write_string("String")
    Float32 => out.write_string("(_ FloatingPoint 8 24)")
    Float64 => out.write_string("(_ FloatingPoint 11 53)")
    BitVec(width) => {
      out.write_string("(_ BitVec ")
      write_int(out, width)
      out.write_string(")")
    }
    Array(index, element) => {
      out.write_string("(Array ")
      index.write(out)
      out.write_string(" ")
      element.write(out)
      out.write_string(")")
    }
  }
}

///|
/// The SMT-LIB 2 spelling, such as `(_ BitVec 32)` or `(Array Int String)`.
pub fn Sort::to_smtlib(self : Sort) -> String {
  let out = StringBuilder()
  self.write(out)
  out.to_string()
}
