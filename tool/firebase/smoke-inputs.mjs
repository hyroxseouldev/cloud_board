import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdirSync, readFileSync, readdirSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {hash, root} from './common.mjs';

export const smokeInputDirectory = 'build/release/smoke-inputs';
export const smokeInputNames = ['app-current.json', 'workout-save-current.json'];
const metadataName = 'metadata.json';

export function validateSmokePayloads(workout, app) {
  assert.equal(workout.format, 1, 'Invalid workout smoke input format');
  assert.equal(app.format, 1, 'Invalid playback smoke input format');
  const write = workout.scenarios?.find(value => value.contentOnly === true)?.writes?.[0];
  assert(write?.workout?.author && write.summary, 'Current content-only workout smoke input missing');
  const playback = app.playback?.find(value => value.split === true);
  assert(playback?.state && playback.snapshot?.author, 'Current split playback smoke input missing');
  return {workout, app};
}

// These are candidate DTO exports needed by the retained live smoke, not CI
// results. Keep them outside build/contracts so skipped CI cannot claim success.
export function prepareSmokeInputs({sourceSha, rootDir = root, directory = smokeInputDirectory}) {
  assert.match(sourceSha || '', /^[a-f0-9]{40}$/, 'Exact smoke input source SHA required');
  const bytes = Object.fromEntries(smokeInputNames.map(name => [name, readFileSync(resolve(rootDir, 'build/contracts', name))]));
  validateSmokePayloads(JSON.parse(bytes['workout-save-current.json']), JSON.parse(bytes['app-current.json']));
  const output = resolve(rootDir, directory);
  mkdirSync(output, {recursive: true});
  for (const [name, data] of Object.entries(bytes)) writeFileSync(resolve(output, name), data);
  const metadata = {schemaVersion: 1, kind: 'release-smoke-inputs', sourceSha,
    files: Object.fromEntries(smokeInputNames.map(name => [name, hash(bytes[name])]))};
  writeFileSync(resolve(output, metadataName), `${JSON.stringify(metadata, null, 2)}\n`);
  return verifySmokeInputs({sourceSha, rootDir, directory});
}

export function verifySmokeInputs({sourceSha, rootDir = root, directory = smokeInputDirectory}) {
  assert.match(sourceSha || '', /^[a-f0-9]{40}$/, 'Exact smoke input source SHA required');
  const output = resolve(rootDir, directory);
  const entries = readdirSync(output, {withFileTypes: true});
  assert(entries.every(entry => entry.isFile() && !entry.isSymbolicLink()), 'Smoke inputs must be regular files');
  assert.deepEqual(entries.map(entry => entry.name).sort(), [...smokeInputNames, metadataName].sort(), 'Smoke input inventory mismatch');
  const metadata = JSON.parse(readFileSync(resolve(output, metadataName), 'utf8'));
  assert.equal(metadata.schemaVersion, 1);
  assert.equal(metadata.kind, 'release-smoke-inputs');
  assert.equal(metadata.sourceSha, sourceSha, 'Smoke input source SHA mismatch');
  assert.deepEqual(Object.keys(metadata.files).sort(), smokeInputNames, 'Smoke input hash inventory mismatch');
  const payloads = Object.fromEntries(smokeInputNames.map(name => {
    const bytes = readFileSync(resolve(output, name));
    assert.equal(hash(bytes), metadata.files[name], `Smoke input changed: ${name}`);
    return [name, JSON.parse(bytes)];
  }));
  return validateSmokePayloads(payloads['workout-save-current.json'], payloads['app-current.json']);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const sourceSha = process.env.RELEASE_SOURCE_SHA || process.env.GITHUB_SHA;
  assert.equal(execFileSync('git', ['rev-parse', 'HEAD'], {cwd: root, encoding: 'utf8'}).trim(), sourceSha,
    'Smoke exports must come from the selected candidate checkout');
  if (process.argv[2] === 'prepare') prepareSmokeInputs({sourceSha});
  else if (process.argv[2] === 'verify') verifySmokeInputs({sourceSha});
  else throw new Error('Expected prepare or verify');
  console.log('Current candidate smoke inputs verified; no integration CI result is claimed.');
}
