// Input encodings only. Expected results are computed independently by Z3.
// RNE is the initial runtime profile. NaN payloads and exception flags are excluded.
const bits64 = {
  zero: "0000000000000000", negZero: "8000000000000000",
  one: "3ff0000000000000", negOne: "bff0000000000000",
  two: "4000000000000000", three: "4008000000000000", four: "4010000000000000",
  halfUlp: "3ca0000000000000", nextOne: "3ff0000000000001",
  minSub: "0000000000000001", negMinSub: "8000000000000001",
  maxSub: "000fffffffffffff", minNormal: "0010000000000000",
  max: "7fefffffffffffff", negMax: "ffefffffffffffff",
  inf: "7ff0000000000000", negInf: "fff0000000000000", nan: "7ff8000000000001",
};
const bits32 = {
  zero: "00000000", negZero: "80000000",
  one: "3f800000", negOne: "bf800000",
  two: "40000000", three: "40400000", four: "40800000",
  halfUlp: "33800000", nextOne: "3f800001",
  minSub: "00000001", negMinSub: "80000001",
  maxSub: "007fffff", minNormal: "00800000",
  max: "7f7fffff", negMax: "ff7fffff",
  inf: "7f800000", negInf: "ff800000", nan: "7fc00001",
};

export const formats = {
  32: {width: 32, exponent: 8, precision: 24, suffix: "U", type: "Float", uint: "uint", bits: bits32},
  64: {width: 64, exponent: 11, precision: 53, suffix: "UL", type: "Double", uint: "uint64", bits: bits64},
};

export function casesFor(width) {
  const bits = formats[width]?.bits;
  if (!bits) throw new Error("Unsupported FP width: " + width);
const cases = [];
function add(op, a, b) {
  cases.push({name: op + "/" + a + (b ? "/" + b : ""), op,
    a: bits[a], ...(b ? {b: bits[b]} : {})});
}
for (const [op, a, b] of [
  ["add", "one", "halfUlp"], ["add", "nextOne", "halfUlp"],
  ["add", "minSub", "minSub"], ["add", "maxSub", "minSub"],
  ["add", "max", "max"], ["add", "max", "negMax"],
  ["add", "inf", "negInf"], ["add", "negZero", "negZero"],
  ["add", "zero", "negZero"], ["add", "nan", "one"],
  ["sub", "minNormal", "maxSub"], ["sub", "one", "one"],
  ["sub", "negZero", "zero"], ["sub", "inf", "inf"],
  ["sub", "max", "negMax"], ["sub", "one", "nan"],
  ["mul", "minSub", "one"], ["mul", "minSub", "two"],
  ["mul", "max", "two"], ["mul", "zero", "inf"],
  ["mul", "negZero", "negOne"], ["mul", "zero", "negOne"],
  ["mul", "nan", "two"],
  ["div", "one", "three"], ["div", "one", "zero"],
  ["div", "one", "negZero"], ["div", "zero", "zero"],
  ["div", "inf", "inf"], ["div", "one", "inf"],
  ["div", "negOne", "inf"], ["div", "minSub", "two"],
  ["div", "negMinSub", "two"], ["div", "minNormal", "two"],
  ["div", "nan", "one"],
]) add(op, a, b);
for (const a of ["zero", "negZero", "one", "two", "four", "negOne",
  "minSub", "maxSub", "minNormal", "max", "inf", "nan"]) add("sqrt", a);

// Sign operations have no rounding mode; include zeros, infinities, and NaNs.
for (const op of ["neg", "abs"]) for (const a of Object.keys(bits)) add(op, a);

// Small reproducible sample across all bit encodings; this is not exhaustive.
let state = 0x6a09e667f3bcc909n;
function nextBits() {
  state ^= state << 13n;
  state ^= state >> 7n;
  state ^= state << 17n;
  state = BigInt.asUintN(64, state);
  return BigInt.asUintN(width, state).toString(16).padStart(width / 4, "0");
}
for (const op of ["add", "sub", "mul", "div", "sqrt"]) {
  for (let index = 0; index < 8; index++) {
    cases.push({name: op + "/sample-" + index, op, a: nextBits(),
      ...(op === "sqrt" ? {} : {b: nextBits()})});
  }
}
return cases;
}
