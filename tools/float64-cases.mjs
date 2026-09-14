// Input encodings only. Expected results are computed independently by Z3.
// RNE is the initial runtime profile. NaN payloads and exception flags are excluded.
const bits = {
  zero: "0000000000000000", negZero: "8000000000000000",
  one: "3ff0000000000000", negOne: "bff0000000000000",
  two: "4000000000000000", three: "4008000000000000", four: "4010000000000000",
  halfUlp: "3ca0000000000000", nextOne: "3ff0000000000001",
  minSub: "0000000000000001", negMinSub: "8000000000000001",
  maxSub: "000fffffffffffff", minNormal: "0010000000000000",
  max: "7fefffffffffffff", negMax: "ffefffffffffffff",
  inf: "7ff0000000000000", negInf: "fff0000000000000", nan: "7ff8000000000001",
};
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

// Small reproducible sample across all bit encodings; this is not exhaustive.
let state = 0x6a09e667f3bcc909n;
function nextBits() {
  state ^= state << 13n;
  state ^= state >> 7n;
  state ^= state << 17n;
  state = BigInt.asUintN(64, state);
  return state.toString(16).padStart(16, "0");
}
for (const op of ["add", "sub", "mul", "div", "sqrt"]) {
  for (let index = 0; index < 8; index++) {
    cases.push({name: op + "/sample-" + index, op, a: nextBits(),
      ...(op === "sqrt" ? {} : {b: nextBits()})});
  }
}
export { cases };
