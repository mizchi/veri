import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

export const cvc5Version = "1.3.4";
export const solverDirectory = fileURLToPath(new URL("../_build/solvers/", import.meta.url));

// SHA-256 digests from the official cvc5-1.3.4 GitHub release assets.
const assets = {
  "darwin-arm64": ["macOS-arm64", "3840aa53f6ee6fc357415dcfe291d7f5ffec6cfb1ccca6fef64120a0d2be4cb6"],
  "darwin-x64": ["macOS-x86_64", "5a7976affaf37dcf03ee44c3d0297c8e0ba08afd44ac832dab97400da726b852"],
  "linux-arm64": ["Linux-arm64", "2a4c108367f20b0c8990abd6b9535a5d62e08908d471d4671c00734e408f85bc"],
  "linux-x64": ["Linux-x86_64", "dcdbfada0ce493ee98259c0816e0daafc561c223aadb3af298c2968e73ea39c6"],
};

export function cvc5Asset(platform = process.platform, arch = process.arch) {
  const asset = assets[platform + "-" + arch];
  if (!asset) throw new Error("Unsupported CVC5 bootstrap target: " + platform + "-" + arch + "; set VERI_CVC5 to an installed executable");
  return {name: "cvc5-" + asset[0] + "-static", sha256: asset[1]};
}

export function verifyArchive(bytes, expected) {
  if (createHash("sha256").update(bytes).digest("hex") !== expected) {
    throw new Error("CVC5 archive checksum mismatch");
  }
}

export function parseCvc5Version(output) {
  const match = output.match(/^(?:This is )?cvc5 (?:version )?(\d+\.\d+\.\d+)\b/);
  if (!match) throw new Error("Unrecognized CVC5 version output");
  return match[1];
}

export function cvc5Path() {
  return process.env.VERI_CVC5 || join(solverDirectory, cvc5Version, cvc5Asset().name, "bin/cvc5");
}

export function installedCvc5() {
  const command = cvc5Path();
  if (!process.env.VERI_CVC5 && !existsSync(command)) {
    throw new Error("CVC5 is missing; run just setup-solvers or set VERI_CVC5");
  }
  const version = parseCvc5Version(execFileSync(command, ["--version"], {encoding: "utf8"}));
  return {command, version};
}
