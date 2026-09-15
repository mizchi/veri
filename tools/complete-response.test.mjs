import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

const root = resolve(import.meta.dirname, '..');
function invoke(args) {
  const p = spawnSync('moonx', ['veri.mbtx', ...args], {
    cwd: root, encoding: 'utf8', timeout: 180000, maxBuffer: 16 * 1024 * 1024,
  });
  assert.ifError(p.error);
  return p;
}
const job = ['check', 'temporal/driver', '--module', 'examples', '--config', '{"allow_drop":false}',
  '--response', 'pending', 'done', '--complete'];

test('complete response checks fairness and saves replayable certificates without Z3', () => {
  const directory = mkdtempSync(join(tmpdir(), 'veri-complete-'));
  const file = join(directory, 'trace.json');
  try {
    let p = invoke([...job, '--z3', '/nonexistent-z3', '--save', file]);
    assert.equal(p.status, 0, p.stderr);
    assert.equal(JSON.parse(p.stdout).result, 'counterexample');
    const bundle = JSON.parse(readFileSync(file, 'utf8'));
    assert.equal(bundle.complete, true);
    assert.equal(bundle.result.bound, bundle.result.witness.actions.length);
    for (const command of ['explain', 'replay-file']) {
      p = invoke([command, file]);
      assert.equal(p.status, 0, p.stderr);
    }
    p = invoke([...job, '--fair', '--require-trigger', '--save', file]);
    assert.equal(p.status, 0, p.stderr);
    assert.equal(JSON.parse(p.stdout).result, 'safe-for-complete-model');
    p = invoke(['explain', file]);
    assert.notEqual(p.status, 0);
    for (const extra of [['--bound', '4'], ['--timeout-ms', '100']]) {
      assert.notEqual(invoke([...job, ...extra]).status, 0);
    }
    const empty = {initial:0,actions:['wait'],states:[0],transitions:[[0]],justice:[],
      predicates:{pending:[false],done:[false]}};
    p = invoke(['check','workflows/raw','--module','examples','--config',JSON.stringify(empty),
      '--response','pending','done','--complete','--require-trigger']);
    assert.notEqual(p.status,0);
    assert.match(p.stderr,/TriggerUnreachableInCompleteModel/);
  } finally { rmSync(directory, {recursive:true,force:true}); }
});

test('complete response covers all TaskGroup policies and the lost-request control', () => {
  for (let policy=0; policy<16; policy++) {
    const p=invoke(['check','task_group/driver','--module','examples',
      '--config',JSON.stringify({policy,fault:0}),'--response','closing','returned',
      '--complete','--fair','--require-trigger']);
    assert.equal(p.status,0,p.stderr);
    assert.equal(JSON.parse(p.stdout).result,'safe-for-complete-model',`policy ${policy}`);
  }
  const args=job.map(value => value === '{"allow_drop":false}' ? '{"allow_drop":true}' : value);
  const p=invoke([...args,'--fair']);
  assert.equal(p.status,0,p.stderr);
  assert.equal(JSON.parse(p.stdout).result,'counterexample');
});

test('CI suites support complete fair response and reject inapplicable fairness', () => {
  const directory = mkdtempSync(join(tmpdir(), 'veri-complete-suite-'));
  const file = join(directory,'suite.json');
  try {
    const base = {driver:'temporal/driver',module_dir:join(root,'examples'),config:{allow_drop:false},
      property:{kind:'response',trigger:'pending',goal:'done'},complete:true};
    writeFileSync(file,JSON.stringify({version:1,cases:[
      {...base,name:'unfair',expect:'counterexample'},
      {...base,name:'fair',fair:true,require_trigger:true,expect:'safe-for-complete-model'},
    ]}));
    let p=invoke(['test',file]);
    assert.equal(p.status,0,p.stderr);
    assert.equal(JSON.parse(p.stdout).passed,true);
    writeFileSync(file,JSON.stringify({version:1,cases:[{...base,name:'invalid',fair:true,
      property:{kind:'safety',predicate:'safe'},expect:'safe-for-complete-model'}]}));
    p=invoke(['test',file]);
    assert.notEqual(p.status,0);
  } finally {rmSync(directory,{recursive:true,force:true});}
});
