// SMT-LIB string semantics over validated UTF-16. Positions and lengths count
// code points, as in `runtime/text`.

///|
/// Saturate to a range in which every string position fits.
fn clamp(value : @bigint.BigInt) -> Int32 {
  if value > 0x3fff_ffffN {
    0x3fff_ffff
  } else if value < -0x3fff_ffffN {
    -0x3fff_ffff
  } else {
    value.to_int()
  }
}

///|
/// `str.substr`: empty for an invalid start or nonpositive count.
fn str_substr(text : String, start : Int32, count : Int32) -> String {
  let length = text.char_length()
  if start < 0 || start >= length || count <= 0 {
    return ""
  }
  let count = if count > length - start { length - start } else { count }
  if start == 0 && count == length {
    return text
  }
  let first = text.offset_of_nth_char(start).unwrap()
  let last = if start + count == length {
    text.length()
  } else {
    text.offset_of_nth_char(start + count).unwrap()
  }
  text.exact_view(start=first, end=last).to_owned()
}

///|
/// First code unit offset of `part` in `text` at or after `from`.
fn find_from(text : String, part : String, from : Int32) -> Int32? {
  match text.exact_view(start=from, end=text.length()).find(part) {
    Some(offset) => Some(from + offset)
    None => None
  }
}

///|
/// `str.indexof`, in code points.
fn str_index_of(text : String, part : String, start : Int32) -> Int32 {
  let length = text.char_length()
  if start < 0 || start > length {
    return -1
  }
  if part.is_empty() {
    return start
  }
  let from = if start == length {
    text.length()
  } else {
    text.offset_of_nth_char(start).unwrap()
  }
  match find_from(text, part, from) {
    Some(offset) => start + text.char_length(start=from, end=offset)
    None => -1
  }
}

///|
/// `str.replace`: the first occurrence only; an empty pattern prepends.
fn str_replace(text : String, from : String, to : String) -> String {
  if from.is_empty() {
    return to + text
  }
  match find_from(text, from, 0) {
    None => text
    Some(offset) => {
      let out = StringBuilder(size_hint=text.length() + to.length())
      out.write_substring(text, 0, offset)
      out.write_string(to)
      let rest = offset + from.length()
      out.write_substring(text, rest, text.length() - rest)
      out.to_string()
    }
  }
}

///|
/// `str.to_int`: -1 unless the string is a nonempty run of ASCII digits.
fn str_to_int(text : String) -> @bigint.BigInt {
  if text.is_empty() {
    return -1N
  }
  for index in 0..<text.length() {
    let unit = text.unsafe_get(index).to_int()
    if unit < '0' || unit > '9' {
      return -1N
    }
  }
  @bigint.BigInt::from_string(text)
}

///|
/// Lexicographic comparison by code point. UTF-16 code unit order differs
/// from it between U+E000..U+FFFF and the supplementary planes.
fn str_compare(a : String, b : String) -> Int32 {
  let x = a.iter()
  let y = b.iter()
  while true {
    match (x.next(), y.next()) {
      (None, None) => return 0
      (None, Some(_)) => return -1
      (Some(_), None) => return 1
      (Some(p), Some(q)) => if p != q { return p.to_int().compare(q.to_int()) }
    }
  }
  0
}
