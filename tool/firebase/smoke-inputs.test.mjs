import assert from 'node:assert/strict';
import test from 'node:test';
import {mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {prepareSmokeInputs, verifySmokeInputs, smokeInputDirectory} from './smoke-inputs.mjs';

const sha = 'a'.repeat(40);
const payloads = {
  'workout-save-current.json': {format: 1, scenarios: [{contentOnly: true, writes: [{workout: {author: {id: 'candidate'}, name: 'current candidate'}, summary: {name: 'current candidate'}}]}]},
  'app-current.json': {format: 1, playback: [{split: true, state: {revision: 9}, snapshot: {author: {id: 'candidate'}}}]},
};

function fixture(task) {
  const rootDir = mkdtempSync(join(tmpdir(), 'cloudboard-smoke-inputs-'));
  try {
    mkdirSync(join(rootDir, 'build/contracts'), {recursive: true});
    for (const [name, payload] of Object.entries(payloads)) {
      writeFileSync(join(rootDir, 'build/contracts', name), `${JSON.stringify(payload)}\n`);
    }
    task(rootDir);
  } finally { rmSync(rootDir, {recursive: true, force: true}); }
}

test('skipped CI smoke retains exact current candidate payloads without contract results', () => fixture(rootDir => {
  const result = prepareSmokeInputs({sourceSha: sha, rootDir});
  assert.deepEqual(result, {workout: payloads['workout-save-current.json'], app: payloads['app-current.json']});
  for (const name of Object.keys(payloads)) {
    assert.deepEqual(readFileSync(join(rootDir, smokeInputDirectory, name)), readFileSync(join(rootDir, 'build/contracts', name)));
  }
  rmSync(join(rootDir, 'build/contracts'), {recursive: true});
  assert.deepEqual(verifySmokeInputs({sourceSha: sha, rootDir}), result, 'skip path must not need contract CI artifacts');
  assert.throws(() => verifySmokeInputs({sourceSha: 'b'.repeat(40), rootDir}), /source SHA mismatch/);
}));

test('smoke preflight rejects modified, missing, malformed or unrelated payloads', () => fixture(rootDir => {
  prepareSmokeInputs({sourceSha: sha, rootDir});
  const output = join(rootDir, smokeInputDirectory);
  writeFileSync(join(output, 'app-current.json'), '{}');
  assert.throws(() => verifySmokeInputs({sourceSha: sha, rootDir}), /Smoke input changed/);
  prepareSmokeInputs({sourceSha: sha, rootDir});
  rmSync(join(output, 'app-current.json'));
  assert.throws(() => verifySmokeInputs({sourceSha: sha, rootDir}), /inventory mismatch/);
  writeFileSync(join(rootDir, 'build/contracts/app-current.json'), JSON.stringify({format: 1, playback: []}));
  assert.throws(() => prepareSmokeInputs({sourceSha: sha, rootDir}), /split playback/);
  assert.throws(() => prepareSmokeInputs({sourceSha: '', rootDir}), /Exact smoke input source SHA/);
}));
