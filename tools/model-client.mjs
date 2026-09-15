import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import {fileURLToPath} from "node:url";
import {checkFinite, validateFiniteModel} from "./finite-temporal.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));

/** Versioned transport shared by all models. Configuration belongs to the adapter;
 * properties and witnesses use the same format as finite-temporal and Apalache. */
export function createModelClient({driver, cwd = root, moduleDir = "examples", target = "js",
  defaults = {}, execute = execFileSync}) {
  assert.equal(typeof driver, "string");
  const request = (mode, config, property, justice, witnesses) => {
    const input = {version: 1, mode, config: {...defaults, ...config}, property, justice,
      witnesses: witnesses.map(({states, actions, loop}) => {
        assert.ok(loop === null || Number.isInteger(loop), "Witness requires loop: null or an integer");
        return {states, actions, ...(loop === null ? {} : {loop_start: loop})};
      })};
    const output = JSON.parse(execute("moon", ["-C", moduleDir, "run", driver, "--target", target,
      "--deny-warn", "--", JSON.stringify(input)], {
      cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], timeout: 60000, maxBuffer: 16 * 1024 * 1024,
    }));
    assert.equal(output.version, 1, "Unsupported model driver response version");
    assert.ok(Object.hasOwn(output, "result"), "Missing model driver result");
    return output.result;
  };
  const load = (config = {}) => validateFiniteModel(request("export", config, undefined, [], []));
  const replay = (witnesses, {config = {}, property, justice = []} = {}) => {
    assert.ok(property, "Replay requires a property");
    const result = request("replay", config, property, justice, witnesses);
    assert.ok(Array.isArray(result), "Replay must return an array");
    assert.equal(result.length, witnesses.length, "Replay result length mismatch");
    assert.ok(result.every(value => typeof value === "boolean"), "Replay must return booleans");
    return result;
  };
  const check = (property, {config = {}, justice = [], ...options} = {}) => {
    const model = load(config);
    const found = checkFinite(model, property, {...options, justice});
    if (found.witness) {
      assert.deepEqual(replay([found.witness], {config, property, justice}), [true],
        "Solver witness must replay in the actual MoonBit model");
    }
    return found;
  };
  return {load, replay, check};
}
