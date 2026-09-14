import { formats } from "./float-cases.mjs";
import { runZ3 } from "./solver.mjs";

export function fpLiteral(width, bits) {
  const format = formats[width];
  if (!format || !new RegExp("^[0-9a-f]{" + width / 4 + "}$").test(bits)) {
    throw new Error("Invalid binary" + width + " input encoding: " + bits);
  }
  return "((_ to_fp " + format.exponent + " " + format.precision + ") #x" + bits + ")";
}

// null denotes any NaN. All finite values, infinities, and signed zeros have
// exact reference encodings. Expected results never use host FP arithmetic.
export function referenceBits(width, expressions) {
  if (!formats[width]) throw new Error("Unsupported FP width: " + width);
  const sentinel = "f".repeat(width / 4); // A NaN encoding, never a non-NaN result.
  const query = expressions.map(expr => "(simplify (ite (fp.isNaN " + expr + ") #x" +
    sentinel + " (fp.to_ieee_bv " + expr + ")))").join("\n");
  const answers = runZ3(query).trim().split(/\r?\n/);
  if (answers.length !== expressions.length || answers.some(line => !new RegExp("^#x[0-9a-f]{" + width / 4 + "}$").test(line))) {
    throw new Error("Unexpected FP reference output: " + answers.join("\n"));
  }
  return answers.map(line => line.slice(2) === sentinel ? null : line.slice(2));
}

export function referenceBools(expressions) {
  const answers = runZ3(expressions.map(expr => "(simplify " + expr + ")").join("\n")).trim().split(/\r?\n/);
  if (answers.length !== expressions.length || answers.some(line => !/^(true|false)$/.test(line))) {
    throw new Error("Unexpected FP predicate output: " + answers.join("\n"));
  }
  return answers;
}
