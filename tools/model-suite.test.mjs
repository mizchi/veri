import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync, chmodSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {checkFinite} from './finite-temporal.mjs';

const root = resolve(import.meta.dirname, '..');
function invoke(file, extra = []) {
  const p = spawnSync('moonx', ['veri.mbtx', 'test', file, ...extra], {
    cwd: root, encoding: 'utf8', timeout: 180000, maxBuffer: 16 * 1024 * 1024,
  });
  assert(!p.error, String(p.error));
  return p;
}
const safety = {kind: 'safety', predicate: 'safe'};
function example(name, property, expect) {
  return {name, driver: 'temporal/driver', module_dir: join(root, 'examples'),
    config: {allow_drop: false}, property, bound: 3, expect};
}
test('suite runs expected counterexamples and successes, reports mismatches and solver errors', () => {
  const directory = mkdtempSync(join(tmpdir(), 'veri-suite-'));
  const file = join(directory, 'suite.json');
  try {
    const cases = [example('safe', safety, 'no-counterexample-up-to-bound'),
      example('wait', {kind: 'response', trigger: 'pending', goal: 'done'}, 'counterexample'),
      example('done', {kind: 'reachability', predicate: 'done'}, 'witness')];
    writeFileSync(file, JSON.stringify({version: 1, cases}));
    let p = invoke(file);
    assert.equal(p.status, 0, p.stderr);
    let report = JSON.parse(p.stdout);
    assert.equal(report.passed, true);
    assert.equal(report.cases.length, 3);
    assert(report.cases.every(c => c.passed));
    cases[0].expect = 'counterexample';
    writeFileSync(file, JSON.stringify({version: 1, cases}));
    p = invoke(file);
    assert.notEqual(p.status, 0);
    report = JSON.parse(p.stdout);
    assert.equal(report.passed, false);
    assert.deepEqual(report.cases.map(c => c.passed), [false, true, true]);
    const solver = join(directory, 'unknown-z3');
    writeFileSync(solver, '#!/bin/sh\nprintf "unknown\\n"\n');
    chmodSync(solver, 0o755);
    p = invoke(file, ['--z3', solver]);
    assert.notEqual(p.status, 0);
    report = JSON.parse(p.stdout);
    assert(report.cases.every(c => !c.passed && c.error));
    for (const invalid of [{version: 2, cases}, {version: 1, cases: []},
      {version: 1, cases: [cases[0], cases[0]]},
      {version: 1, cases: [{...cases[0], expect: 'proved'}]},
      {version: 1, cases: [{...cases[0], requireTrigger: true}]},
      {version: 1, cases: [{...cases[0], fair: true, justice: []}]}]) {
      writeFileSync(file, JSON.stringify(invalid));
      assert.notEqual(invoke(file).status, 0);
    }
  } finally { rmSync(directory, {recursive: true, force: true}); }
});

test('saved traces explain state changes and replay only against the same model', () => {
  const directory = mkdtempSync(join(tmpdir(), 'veri-trace-'));
  const file = join(directory, 'trace.json');
  const invoke = args => spawnSync('moonx', ['veri.mbtx', ...args], {
    cwd: root, encoding: 'utf8', timeout: 180000, maxBuffer: 16 * 1024 * 1024,
  });
  try {
    let p = invoke(['check', 'lease_clock/driver', '--module', 'examples',
      '--config', '{"variant":0,"bound":4}', '--safety', 'single_writer', '--bound', '4', '--save', file]);
    assert.equal(p.status, 0, p.stderr);
    p = invoke(['explain', file]);
    assert.equal(p.status, 0, p.stderr);
    const explanation = JSON.parse(p.stdout);
    assert.equal(explanation.steps.length, 4);
    assert.equal(explanation.steps[0].action, 'advance-time');
    assert(explanation.steps[0].changes.some(c => c.path === '/now' && c.before === 0 && c.after === 1));
    assert.equal(explanation.violation_at, 4);
    p = invoke(['replay-file', file]);
    assert.equal(p.status, 0, p.stderr);
    assert.equal(JSON.parse(p.stdout).accepted, true);
    const data = JSON.parse(readFileSync(file, 'utf8'));
    data.config.variant = 1;
    writeFileSync(file, JSON.stringify(data));
    p = invoke(['replay-file', file]);
    assert.notEqual(p.status, 0);
  } finally { rmSync(directory, {recursive: true, force: true}); }
});

test('required response triggers cannot pass vacuously', () => {
  const p = spawnSync('moonx', ['veri.mbtx', 'check', 'temporal/driver', '--module', 'examples',
    '--config', '{"allow_drop":false}', '--response', 'done', 'safe', '--bound', '1', '--require-trigger'],
    {cwd:root, encoding:'utf8', timeout:180000});
  assert.notEqual(p.status, 0);
  assert.match(p.stderr, /TriggerUnreachable/);
});

test('deadlock checking distinguishes terminal states and enabled self loops', () => {
  for (const mode of [0,1,2]) {
    const p = spawnSync('moonx', ['veri.mbtx', 'check', 'workflows/driver', '--module', 'examples',
      '--config', JSON.stringify({mode}), '--deadlock', 'terminal', '--bound', '2'],
      {cwd:root, encoding:'utf8', timeout:180000});
    assert.equal(p.status,0,p.stderr);
    const result = JSON.parse(p.stdout);
    assert.equal(result.result, mode === 1 ? 'counterexample' : 'no-counterexample-up-to-bound');
    if (mode === 1) assert.equal(result.bound, 1);
  }
});

test('large bounds use one Z3 process and complete checks reject partial models', () => {
  const directory = mkdtempSync(join(tmpdir(), 'veri-incremental-'));
  try {
    const wrapper = join(directory, 'z3-wrapper'), log = join(directory, 'spawns');
    writeFileSync(wrapper, '#!/bin/sh\necho run >> "$VERI_SPAWN_LOG"\nexec z3 "$@"\n');
    chmodSync(wrapper,0o755);
    const call = args => spawnSync('moonx',['veri.mbtx',...args], {
      cwd:root, encoding:'utf8', timeout:180000, env:{...process.env,VERI_SPAWN_LOG:log},
    });
    const base = ['check','temporal/driver','--module','examples','--config','{"allow_drop":false}','--safety','safe'];
    let p = call([...base,'--bound','32','--z3',wrapper]);
    assert.equal(p.status,0,p.stderr);
    assert.equal(JSON.parse(p.stdout).bound,32);
    assert.equal(readFileSync(log,'utf8').trim().split('\n').length,1);
    p=call([...base,'--complete']);
    assert.equal(p.status,0,p.stderr);
    assert.equal(JSON.parse(p.stdout).result,'safe-for-complete-model');
    p=call(['check','lease_clock/driver','--module','examples','--config','{"variant":0,"bound":1}',
      '--safety','single_writer','--complete']);
    assert.notEqual(p.status,0);
    for(const flags of [['--max-query-bytes','1'],['--max-output-bytes','1'],['--memory-mb','0']]) {
      p=call([...base,...flags]);
      assert.notEqual(p.status,0);
    }
    const sleeper=join(directory,'sleeping-z3');
    writeFileSync(sleeper,'#!/bin/sh\nexec sleep 30\n');chmodSync(sleeper,0o755);
    const start=Date.now();
    p=call([...base,'--z3',sleeper,'--timeout-ms','100']);
    assert.notEqual(p.status,0);
    assert(Date.now()-start<5000);
  } finally {rmSync(directory,{recursive:true,force:true});}
});

test('incremental MoonBit encoding agrees with the independent oracle on generated finite graphs', () => {
  let seed=20260916;
  const random=n=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return (seed>>>8)%n;};
  for(let sample=0;sample<6;sample++){
    const model={initial:0,actions:['a','b'],states:[0,1,2],justice:[0],
      transitions:Array.from({length:3},()=>Array.from({length:2},()=>random(4)-1)),
      predicates:{p:Array.from({length:3},()=>!!random(2)),q:Array.from({length:3},()=>!!random(2))}};
    for(const [property,flags,justice] of [
      [{kind:'safety',predicate:'p'},['--safety','p'],[]],
      [{kind:'reachability',predicate:'q'},['--reachable','q'],[]],
      [{kind:'response',trigger:'p',goal:'q'},['--response','p','q','--justice','[0]'],[0]],
    ]){
      const expected=checkFinite(model,property,{bound:3,justice});
      const p=spawnSync('moonx',['veri.mbtx','check','workflows/raw','--module','examples',
        '--config',JSON.stringify(model),...flags,'--bound','3'],{cwd:root,encoding:'utf8',timeout:180000});
      assert.equal(p.status,0,p.stderr);
      const actual=JSON.parse(p.stdout);
      assert.equal(actual.result,expected.result,JSON.stringify(model));
      assert.equal(actual.bound,expected.bound);
    }
  }
});
