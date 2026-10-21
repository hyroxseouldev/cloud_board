import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {clientFixtureFiles, validateFixtures, validateCurrentContracts} from './fixtures.mjs';
import {readJson, hash} from './common.mjs';

const registry = readJson('tool/firebase/supported-clients.json');
const files = clientFixtureFiles(registry);
const read = file => readFileSync(file);
const baseline = Object.fromEntries(files.map(file => [file, hash(read(file))]));

test('released contracts map exact iOS, Android, TV and web builds to shared source', () => {
  validateFixtures(registry, files, read, baseline, registry);
  const released = registry.clients.find(c => c.sourceCommit === 'a8653077314c5e5bf2f14e1a8495e4c9ab1f1b6b');
  assert.deepEqual(released.releases.map(r => `${r.platform}/${r.build}`), ['ios/553', 'android/65', 'tv/65', 'web/142.1']);
});

test('released registry metadata cannot silently drop support or rename a build', () => {
  for (const mutate of [
    r => r.clients[0].platforms.push('android'),
    r => r.clients[1].schemas.pop(),
    r => r.clients[1].releases[0].build = '554',
    r => r.clients.pop(),
  ]) {
    const changed = structuredClone(registry);
    mutate(changed);
    assert.throws(() => validateFixtures(changed, files, read, baseline, registry));
  }
});

test('released settings and TV fixtures cannot be replaced by regenerating their digest', () => {
  const changed = structuredClone(registry), client = changed.clients[1];
  const fixture = JSON.parse(read(client.appContract.file));
  fixture.playback[0].state.remainingMs = 30000;
  const bytes = Buffer.from(JSON.stringify(fixture));
  client.appContract.sha256 = hash(bytes);
  assert.throws(() => validateFixtures(changed, files,
    file => file === client.appContract.file ? bytes : read(file), baseline, registry), /overwritten/);
});

// A historical payload cannot stand in for the latest released wire shape.
const released = registry.clients.find(client => client.sourceCommit === 'ca86c80c95da701299f91fd3a7cb82a003faf0ce');
const currentWorkout = readJson(released.file), currentApp = readJson(released.appContract.file);
function readCandidate(workout = currentWorkout, app = currentApp) {
  return file => file === 'build/contracts/workout-save-current.json' ? JSON.stringify(workout)
    : file === 'build/contracts/app-current.json' ? JSON.stringify(app) : read(file);
}
test('released wire fields, types and protocol versions remain readable', () => {
  validateCurrentContracts(registry, readCandidate());
  for (const mutate of [
    w => delete w.scenarios[0].writes[0].workout.modules[0].workSeconds,
    w => w.scenarios[0].writes[0].workout.modules[0].workSeconds = '60',
    w => w.scenarios[3].writes[0].workout.schemaVersion = 3,
  ]) {
    const workout = structuredClone(currentWorkout);
    mutate(workout);
    assert.throws(() => validateCurrentContracts(registry, readCandidate(workout)), /Released wire/);
  }
  const app = structuredClone(currentApp);
  app.playback[1].state.schemaVersion = 3;
  assert.throws(() => validateCurrentContracts(registry, readCandidate(currentWorkout, app)), /Released wire/);
});

test('an optional additive wire field does not erase any supported reader contract', () => {
  const workout = structuredClone(currentWorkout);
  workout.scenarios[0].writes[0].workout.modules[0].futureOptionalMetadata = {color: 'sage'};
  validateCurrentContracts(registry, readCandidate(workout));
});

test('an older payload cannot replace the latest released client contract', () => {
  const older = registry.clients.find(client => client.sourceCommit === 'a8653077314c5e5bf2f14e1a8495e4c9ab1f1b6b');
  assert.throws(() => validateCurrentContracts(registry, readCandidate(readJson(older.file), readJson(older.appContract.file))),
    /Released wire type changed: 2\.0\.0-release-ca86c80c95da\/.*\/workGaugeColor/);
});

test('pre-EMOM public/review fixtures describe only timer features those apps wrote', () => {
  for (const client of registry.clients.filter(c => c.capabilities)) {
    const fixture = readJson(client.file);
    assert.deepEqual(fixture.scenarios.map(s => s.name), ['legacy-fixed', 'content-fixed']);
    assert.deepEqual(client.capabilities.durationKinds, ['fixed']);
    assert(fixture.scenarios.every(s => s.writes.every(w => !Object.hasOwn(w.summary, 'durationKind'))));
    assert.equal(fixture.provenance.kind, 'exported-with-historical-source-harness');
    assert.equal(fixture.provenance.sourceBlobs['pubspec.lock'].length, 40);
  }
  const changed = structuredClone(registry);
  const historical = changed.clients.find(c => c.sourceCommit === 'c54588cc7733ac8577d11c036c21635d1f283f2a');
  historical.capabilities.summaryDurationKind = true;
  assert.throws(() => validateFixtures(changed, files, read), /Historical summary capability/);
});

test('current fixed-timer scenario cannot disappear behind historical capability metadata', () => {
  const workout = structuredClone(currentWorkout);
  workout.scenarios = workout.scenarios.filter(s => s.name !== 'legacy-fixed');
  const historicalOnly = {...registry, clients: registry.clients.filter(c => c.capabilities)};
  assert.throws(() => validateCurrentContracts(historicalOnly, readCandidate(workout)), /Released wire field removed/);
});
