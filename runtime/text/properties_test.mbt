///|
// Map arbitrary unsigned values onto exactly the SMT Unicode scalar alphabet.
fn smt_string(codes : Array[UInt]) -> String {
  let builder = StringBuilder()
  for value in codes {
    let index = (value % 0x2f800U).reinterpret_as_int()
    let code = if index < 0xd800 { index } else { index + 0x800 }
    builder.write_char(code.to_char().unwrap())
  }
  builder.to_string()
}

///|
// Independent reference: iterate scalars instead of calculating UTF-16 offsets.
fn scalar_substring(source : String, start : Int, count : Int) -> String {
  let builder = StringBuilder()
  if start >= 0 && count > 0 {
    for index, char in source.iter().iter2() {
      if index >= start && index - start < count {
        builder.write_char(char)
      }
    }
  }
  builder.to_string()
}

///|
test "quickcheck: text accepts exactly the SMT alphabet in valid Unicode" {
  @quickcheck.check(
    (source : String) => {
      let valid = source.iter().all(char => char.to_int() <= 0x2ffff)
      match @text.from_string(source) {
        Some(text) => valid && text.to_string() == source
        None => !valid
      }
    },
    count=1000,
    max_size=64,
    seed=20260914,
  )
}

///|
test "quickcheck: text length and positions count scalars" {
  @quickcheck.check(
    (codes : Array[UInt]) => {
      let source = smt_string(codes)
      let text = @text.from_string(source).unwrap()
      let mut agrees = text.length() == codes.length()
      for index, char in source.iter().iter2() {
        agrees = agrees && text.char_at(index).to_string() == char.to_string()
      }
      agrees &&
      text.char_at(-1).to_string() == "" &&
      text.char_at(codes.length()).to_string() == ""
    },
    count=1000,
    max_size=64,
    seed=20260914,
  )
}

///|
test "quickcheck: substring matches a scalar iteration reference" {
  @quickcheck.check(
    (input : (Array[UInt], Int, Int, UInt)) => {
      let (codes, start, count, position) = input
      let source = smt_string(codes)
      let text = @text.from_string(source).unwrap()
      // Exercise nearby positions and arbitrary full-width indices/counts.
      let nearby = (position % (codes.length() + 2).reinterpret_as_uint()).reinterpret_as_int() -
        1
      text.substring(start, count).to_string() ==
      scalar_substring(source, start, count) &&
      text.substring(nearby, count).to_string() ==
      scalar_substring(source, nearby, count) &&
      text.substring(nearby, 2147483647).to_string() ==
      scalar_substring(source, nearby, 2147483647)
    },
    count=1000,
    max_size=64,
    seed=20260914,
  )
}

///|
test "quickcheck: text rejects isolated surrogate halves" {
  @quickcheck.check(
    (bits : UInt) => {
      let code = 0x10000 + (bits % 0x20000U).reinterpret_as_int()
      let pair = code.to_char().unwrap().to_string()
      let high = pair.unsafe_substring(start=0, end=1)
      let low = pair.unsafe_substring(start=1, end=2)
      @text.from_string(pair) is Some(_) &&
      @text.from_string(high) is None &&
      @text.from_string(low) is None &&
      @text.from_string(high + "x" + low) is None
    },
    count=1000,
    seed=20260914,
  )
}
