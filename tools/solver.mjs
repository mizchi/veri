import { execFileSync } from "node:child_process";

// Throws on timeout, missing executable, solver error, or unexpected output.
export function runZ3(source) {
  return execFileSync("z3", ["-in", "-smt2"], {
    input: source, encoding: "utf8", timeout: 30_000, maxBuffer: 4 * 1024 * 1024,
  });
}

export function expectStatus(output, expected) {
  const statuses = output.split(/\r?\n/).filter(line => /^(sat|unsat|unknown)$/.test(line));
  if (!['sat', 'unsat'].includes(expected) || output.includes('(error') ||
      statuses.length !== 1 || statuses[0] !== expected) {
    throw new Error('Expected ' + expected + ', received:\n' + output);
  }
  return statuses[0];
}
