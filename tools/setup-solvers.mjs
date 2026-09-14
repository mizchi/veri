import { existsSync, mkdirSync, mkdtempSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { cvc5Asset, cvc5Path, cvc5Version, installedCvc5, solverDirectory, verifyArchive } from "./cvc5.mjs";

if (process.env.VERI_CVC5 || existsSync(cvc5Path())) {
  const installed = installedCvc5();
  console.log("CVC5 " + installed.version + ": " + installed.command);
} else {
  const asset = cvc5Asset();
  const url = "https://github.com/cvc5/cvc5/releases/download/cvc5-" + cvc5Version + "/" + asset.name + ".zip";
  console.log("Downloading CVC5 " + cvc5Version + " from the official release...");
  const response = await fetch(url, {signal: AbortSignal.timeout(120_000)});
  if (!response.ok) throw new Error("CVC5 download failed: HTTP " + response.status);
  const bytes = Buffer.from(await response.arrayBuffer());
  verifyArchive(bytes, asset.sha256);
  mkdirSync(solverDirectory, {recursive: true});
  const temporary = mkdtempSync(join(solverDirectory, ".cvc5-"));
  try {
    const archive = join(temporary, "cvc5.zip");
    writeFileSync(archive, bytes);
    execFileSync("unzip", ["-q", archive, "-d", temporary]);
    const destination = join(solverDirectory, cvc5Version);
    mkdirSync(destination, {recursive: true});
    // Retain the distribution's license files alongside the executable.
    renameSync(join(temporary, asset.name), join(destination, asset.name));
    const installed = installedCvc5();
    if (installed.version !== cvc5Version) throw new Error("CVC5 archive version mismatch");
    console.log("CVC5 " + installed.version + ": " + installed.command);
  } finally {
    rmSync(temporary, {recursive: true, force: true});
  }
}
