import test from "node:test";
import assert from "node:assert/strict";
import { cvc5Asset, verifyArchive, parseCvc5Version } from "./cvc5.mjs";

test("CVC5 bootstrap selects a pinned platform artifact and rejects unknown targets", () => {
  assert.equal(cvc5Asset("darwin", "arm64").name, "cvc5-macOS-arm64-static");
  assert.equal(cvc5Asset("linux", "x64").name, "cvc5-Linux-x86_64-static");
  assert.throws(() => cvc5Asset("win32", "x64"), /Unsupported/);
  assert.throws(() => cvc5Asset("linux", "riscv64"), /Unsupported/);
  const checksum = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
  verifyArchive(Buffer.from("abc"), checksum);
  assert.throws(() => verifyArchive(Buffer.from("corrupt"), checksum), /checksum/);
});

test("CVC5 version detection accepts the official output formats and rejects noise", () => {
  assert.equal(parseCvc5Version("cvc5 1.3.4 [git f3b21c4]\nlicense"), "1.3.4");
  assert.equal(parseCvc5Version("This is cvc5 version 1.0.0\nlicense"), "1.0.0");
  assert.throws(() => parseCvc5Version("not cvc5 1.3.4"), /Unrecognized/);
});
