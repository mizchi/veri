///|
/// Immutable position within a BytesView. Successful reads return a new cursor;
/// failed reads leave the original available for another parser. No byte copy.
pub struct Cursor {
  priv data : BytesView
  priv offset : Int
}

///|
pub fn Cursor::new(data : BytesView) -> Cursor {
  { data, offset: 0, }
}

///|
pub fn Cursor::position(self : Cursor) -> Int {
  self.offset
}

///|
pub fn Cursor::remaining(self : Cursor) -> Int {
  self.data.length() - self.offset
}

///|
/// Composable read specification. Run through Cursor::read; parser state cannot
/// be forged externally. Native codecs and combinators are differential-tested.
pub struct Parser[T] {
  priv parse : (BytesView, Int) -> @codec.Decoded[T]?
}

///|
pub fn[T] Cursor::read(self : Cursor, parser : Parser[T]) -> (T, Cursor)? {
  match (parser.parse)(self.data, self.offset) {
    None => None
    Some(decoded) =>
      Some((decoded.value, { data: self.data, offset: decoded.next_offset, }))
  }
}

///|
/// Sequential composition commits neither position if either read fails.
pub fn[A, B] Parser::zip(self : Parser[A], next : Parser[B]) -> Parser[(A, B)] {
  {
    parse: (data, offset) => {
      match (self.parse)(data, offset) {
        None => None
        Some(first) =>
          match (next.parse)(data, first.next_offset) {
            None => None
            Some(second) =>
              Some({
                value: (first.value, second.value),
                next_offset: second.next_offset,
              })
          }
      }
    },
  }
}

///|
/// Transform a successful value without changing consumed length.
pub fn[A, B] Parser::map(self : Parser[A], f : (A) -> B) -> Parser[B] {
  {
    parse: (data, offset) => {
      (self.parse)(data, offset).map(decoded => {
        value: f(decoded.value),
        next_offset: decoded.next_offset,
      })
    },
  }
}

///|
/// Choose a subsequent parser using the first decoded value. Only cursor position
/// is transactional; side effects performed by the callback are not rolled back.
pub fn[A, B] Parser::and_then(
  self : Parser[A],
  f : (A) -> Parser[B],
) -> Parser[B] {
  {
    parse: (data, offset) => {
      match (self.parse)(data, offset) {
        None => None
        Some(first) => (f(first.value).parse)(data, first.next_offset)
      }
    },
  }
}

///|
/// Fallback starts at the original position. Callback side effects are not undone.
pub fn[T] Parser::or_else(self : Parser[T], other : Parser[T]) -> Parser[T] {
  {
    parse: (data, offset) => {
      match (self.parse)(data, offset) {
        Some(decoded) => Some(decoded)
        None => (other.parse)(data, offset)
      }
    },
  }
}

///|
/// Read exactly count bytes without copying them; reject negative or truncated counts.
pub fn take(count : Int) -> Parser[BytesView] {
  {
    parse: (data, offset) => {
      match @codec.read_end(data.length(), offset, count) {
        None => None
        Some(stop) => Some({ value: data[offset:stop], next_offset: stop, })
      }
    },
  }
}

///|
/// A 32-bit BE length followed by exactly that many bytes. Lengths outside the
/// representable view size fail before converting the UInt length to Int.
pub fn length_prefixed_uint_be() -> Parser[BytesView] {
  uint_be().and_then(length => {
    if length > 2147483647U {
      take(-1)
    } else {
      take(length.reinterpret_as_int())
    }
  })
}
