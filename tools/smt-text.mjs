// SMT-LIB Strings has code points 0..0x2ffff. The runtime adapter further
// excludes surrogates so that every accepted value has well-formed UTF-16.
export function encodeSmtText(value) {
  const codes = [...value].map(c => c.codePointAt(0));
  if (codes.some(code => code > 0x2ffff || (0xd800 <= code && code <= 0xdfff))) {
    throw new Error("Text is outside the runtime/SMT shared alphabet");
  }
  return '"' + codes.map(code => "\\u{" + code.toString(16) + "}").join("") + '"';
}

export function decodeSmtText(encoded) {
  if (!/^"(?:[^"\r\n]|"")*"$/.test(encoded)) throw new Error("Invalid string reference: " + encoded);
  // Decode in one pass: an escaped backslash must not start another escape.
  const value = encoded.slice(1, -1).replace(/""|\\u\{([0-9a-f]+)\}|\\u([0-9a-f]{4})/gi,
    (match, braced, short) => match === '""' ? '"' : String.fromCodePoint(parseInt(braced ?? short, 16)));
  encodeSmtText(value); // Reject reference output outside the supported alphabet.
  return value;
}
