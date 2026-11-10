// Text output primitives.
//
// Everything is appended as whole strings taken from small tables. Appending
// an existing string is one memory copy on the native and Wasm builders and
// one rope append on JavaScript, where appending single characters or
// formatting through 64-bit integers is many times slower.

///|
let decimals : FixedArray[String] = FixedArray::makei(1000, i => i.to_string())

///|
let padded : FixedArray[String] = FixedArray::makei(1000, i => {
  if i < 10 {
    "00" + i.to_string()
  } else if i < 100 {
    "0" + i.to_string()
  } else {
    i.to_string()
  }
})

///|
const HEX : String = "0123456789abcdef"

///|
let hex_digits : FixedArray[String] = FixedArray::makei(16, i => {
  String::make(1, HEX.unsafe_get(i).unsafe_to_char())
})

///|
let hex_bytes : FixedArray[String] = FixedArray::makei(256, i => {
  hex_digits[i >> 4] + hex_digits[i & 15]
})

///|
let binary_nibbles : FixedArray[String] = FixedArray::makei(16, i => {
  let out = StringBuilder()
  for bit = 3; bit >= 0; bit = bit - 1 {
    out.write_string(if ((i >> bit) & 1) == 0 { "0" } else { "1" })
  }
  out.to_string()
})

///|
/// Decimal digits of a nonnegative integer.
fn write_int(out : StringBuilder, value : Int32) -> Unit {
  if value < 0 {
    out.write_string(value.to_string())
  } else if value < 1000 {
    out.write_string(decimals[value])
  } else {
    write_int(out, value / 1000)
    out.write_string(padded[value % 1000])
  }
}

///|
/// The low `digits` hexadecimal digits of `word`, most significant first.
fn write_hex(out : StringBuilder, word : Int32, digits : Int32) -> Unit {
  let mut left = digits
  if left % 2 == 1 {
    left -= 1
    out.write_string(hex_digits[(word >> (left * 4)) & 15])
  }
  while left > 0 {
    left -= 2
    out.write_string(hex_bytes[(word >> (left * 4)) & 255])
  }
}

///|
/// The low `digits` binary digits of `word`, most significant first.
fn write_binary(out : StringBuilder, word : Int32, digits : Int32) -> Unit {
  let mut left = digits
  while left % 4 != 0 {
    left -= 1
    out.write_string(if ((word >> left) & 1) == 0 { "0" } else { "1" })
  }
  while left > 0 {
    left -= 4
    out.write_string(binary_nibbles[(word >> left) & 15])
  }
}

///|
/// A bitvector literal from its two 32-bit halves: hexadecimal when the
/// width is a multiple of four, binary otherwise. Working on halves keeps
/// 64-bit arithmetic, which is arbitrary-precision on JavaScript, off the
/// printing path.
fn write_bits(
  out : StringBuilder,
  width : Int32,
  low : Int32,
  high : Int32,
) -> Unit {
  if width % 4 == 0 {
    out.write_string("#x")
    let digits = width / 4
    if digits > 8 {
      write_hex(out, high, digits - 8)
      write_hex(out, low, 8)
    } else {
      write_hex(out, low, digits)
    }
  } else {
    out.write_string("#b")
    if width > 32 {
      write_binary(out, high, width - 32)
      write_binary(out, low, 32)
    } else {
      write_binary(out, low, width)
    }
  }
}

///|
fn low_half(bits : UInt64) -> Int32 {
  bits.to_uint().reinterpret_as_int()
}

///|
fn high_half(bits : UInt64) -> Int32 {
  (bits >> 32).to_uint().reinterpret_as_int()
}

///|
fn join_bits(low : Int32, high : Int32) -> UInt64 {
  low.reinterpret_as_uint().to_uint64() |
  (high.reinterpret_as_uint().to_uint64() << 32)
}

///|
fn write_integer(out : StringBuilder, value : @bigint.BigInt) -> Unit {
  if value < 0N {
    out.write_string("(- ")
    out.write_string((-value).to_string())
    out.write_string(")")
  } else {
    out.write_string(value.to_string())
  }
}

///|
/// SMT-LIB 2.6 string literal: `"` doubles, and everything outside printable
/// ASCII (and the backslash that would start an escape) becomes `\u{..}`.
/// Runs of plain characters are copied as one substring.
fn write_string_literal(out : StringBuilder, value : String) -> Unit {
  out.write_string("\"")
  let length = value.length()
  let mut start = 0
  let mut index = 0
  while index < length {
    let unit = value.unsafe_get(index).to_int()
    if unit >= 0x20 && unit <= 0x7e && unit != 0x22 && unit != 0x5c {
      index += 1
      continue
    }
    if start < index {
      out.write_substring(value, start, index - start)
    }
    if unit == 0x22 {
      out.write_string("\"\"")
      index += 1
    } else {
      let mut code = unit
      index += 1
      if unit >= 0xd800 && unit <= 0xdbff && index < length {
        let low = value.unsafe_get(index).to_int()
        code = 0x10000 + ((unit - 0xd800) << 10) + (low - 0xdc00)
        index += 1
      }
      out.write_string("\\u{")
      let digits = if code > 0xffff {
        5
      } else if code > 0xfff {
        4
      } else if code > 0xff {
        3
      } else if code > 0xf {
        2
      } else {
        1
      }
      write_hex(out, code, digits)
      out.write_string("}")
    }
    start = index
  }
  if start == 0 {
    out.write_string(value)
  } else if start < length {
    out.write_substring(value, start, length - start)
  }
  out.write_string("\"")
}

///|
fn write_f32(out : StringBuilder, bits : Int32) -> Unit {
  if bits == 0x7fc0_0000 {
    out.write_string("(_ NaN 8 24)")
    return
  }
  out.write_string(if bits < 0 { "(fp #b1 #x" } else { "(fp #b0 #x" })
  write_hex(out, bits >> 23, 2)
  out.write_string(" #b")
  write_binary(out, bits, 23)
  out.write_string(")")
}

///|
fn write_f64(out : StringBuilder, low : Int32, high : Int32) -> Unit {
  if high == 0x7ff8_0000 && low == 0 {
    out.write_string("(_ NaN 11 53)")
    return
  }
  out.write_string(if high < 0 { "(fp #b1 #b" } else { "(fp #b0 #b" })
  write_binary(out, high >> 20, 11)
  out.write_string(" #x")
  write_hex(out, high, 5)
  write_hex(out, low, 8)
  out.write_string(")")
}
