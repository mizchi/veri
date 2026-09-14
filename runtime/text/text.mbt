///|
/// Validated UTF-16 text with scalar indexing, restricted to U+0000..U+2FFFF
/// excluding surrogates. Correspondence with SMT strings is differential-tested.
pub struct Text {
  priv value : String
}

///|
/// Reject unpaired surrogates and code points beyond SMT-LIB's U+2FFFF limit.
pub fn from_string(value : String) -> Text? {
  let mut index = 0
  while index < value.length() {
    let unit = value[index].to_int()
    if 0xd800 <= unit && unit <= 0xdbff {
      // D880 DC00 encodes U+30000, just beyond the SMT alphabet.
      if unit >= 0xd880 {
        return None
      }
      if index == value.length() - 1 {
        return None
      }
      let next = value[index + 1].to_int()
      if next < 0xdc00 || 0xdfff < next {
        return None
      }
      index = index + 2
    } else if 0xdc00 <= unit && unit <= 0xdfff {
      return None
    } else {
      index = index + 1
    }
  }
  Some({ value, })
}

///|
pub fn Text::to_string(self : Text) -> String {
  self.value
}

///|
/// Number of Unicode scalar values, not UTF-16 code units or graphemes.
pub fn Text::length(self : Text) -> Int {
  self.value.char_length()
}

///|
/// SMT str.substr semantics: invalid start or nonpositive count yields empty;
/// a count past the end is truncated. Indices count Unicode scalar values.
pub fn Text::substring(self : Text, start : Int, count : Int) -> Text {
  let length = self.length()
  if start < 0 || start >= length || count <= 0 {
    return { value: "", }
  }
  let count = if count > length - start { length - start } else { count }
  let first = self.value.offset_of_nth_char(start).unwrap()
  let last = if start + count == length {
    self.value.length()
  } else {
    self.value.offset_of_nth_char(start + count).unwrap()
  }
  { value: self.value.sub(start=first, end=last).to_owned(), }
}

///|
/// SMT str.at semantics: one scalar value, or empty for an invalid index.
pub fn Text::char_at(self : Text, index : Int) -> Text {
  self.substring(index, 1)
}
