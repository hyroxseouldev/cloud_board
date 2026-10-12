import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {existsSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {root, readJson, hash, filesIn} from './common.mjs';
import {retirementPolicyFile, validateRetirements} from './support_retirements.mjs';

export const fixtureDirectories = ['functions/test/fixtures/workout-save', 'functions/test/fixtures/app-contracts'];
const registryFile = 'tool/firebase/supported-clients.json';
export const clientFixtureFiles = registry => registry.clients.flatMap(client => [client.file, ...(client.appContract ? [client.appContract.file] : [])]).sort();

export function validateFixtures(registry, files, read, baseline = {}, baselineRegistry = {clients: []}) {
  assert.equal(registry.format, 1);
  assert(registry.clients.length > 0);
  assert.equal(new Set(registry.clients.map(c => c.client)).size, registry.clients.length, 'Duplicate client contract');
  assert.deepEqual(clientFixtureFiles(registry), [...files].sort(), 'Supported-client fixture inventory differs');
  const releasedBuilds = new Set();
  for (const client of registry.clients) {
    assert.match(client.file, /^functions\/test\/fixtures\/workout-save\/[A-Za-z0-9._-]+\.json$/);
    assert.match(client.sourceCommit, /^[a-f0-9]{40}$/);
    assert(client.platforms.length > 0 && client.schemas.length > 0);
    const bytes = read(client.file), data = JSON.parse(bytes);
    assert.equal(hash(bytes), client.sha256, `Frozen fixture changed: ${client.file}`);
    assert.equal(data.client, client.client);
    assert.equal(data.sourceCommit, client.sourceCommit);
    if (client.capabilities) {
      assert.deepEqual(data.scenarios.map(s => s.name), client.capabilities.workoutScenarios);
      assert.deepEqual([...new Set(data.scenarios.map(s => s.durationKind))], client.capabilities.durationKinds);
      for (const scenario of data.scenarios) for (const write of scenario.writes) {
        assert.equal(Object.hasOwn(write.summary, 'durationKind'), client.capabilities.summaryDurationKind,
          `Historical summary capability differs: ${client.client}`);
      }
    }
    if (client.appContract) {
      assert.match(client.appContract.file, /^functions\/test\/fixtures\/app-contracts\/[A-Za-z0-9._-]+\.json$/);
      const appBytes = read(client.appContract.file), app = JSON.parse(appBytes);
      assert.equal(hash(appBytes), client.appContract.sha256, `Frozen fixture changed: ${client.appContract.file}`);
      assert.equal(app.client, client.client);
      assert.equal(app.sourceCommit, client.sourceCommit);
      assert.equal(app.format, 1);
      assert.deepEqual(app.playback.map(p => p.split ? 2 : 1), client.capabilities?.playbackWireProtocols || [1, 2],
        'The fixture must match the released client playback capabilities');
      assert(app.settings?.preferences, 'Released settings contract is required');
      assert(client.releases?.length > 0, 'A released app contract needs platform build evidence');
      assert.deepEqual([...new Set(client.releases.map(r => r.platform))].sort(), [...client.platforms].sort());
    }
    for (const release of client.releases || []) {
      assert(client.platforms.includes(release.platform));
      assert.match(release.version, /^\d+\.\d+\.\d+$/);
      assert.match(release.build, /^\d+(\.\d+)?$/);
      assert.match(release.workflowRunId, /^\d+$/);
      assert(['testflight', 'internal', 'closed', 'production'].includes(release.channel));
      const key = `${release.platform}/${release.version}/${release.build}`;
      assert(!releasedBuilds.has(key), `Duplicate released build: ${key}`);
      releasedBuilds.add(key);
    }
  }
  for (const [file, digest] of Object.entries(baseline)) {
    assert(files.includes(file), `Released fixture removed: ${file}`);
    assert.equal(hash(read(file)), digest, `Released fixture overwritten: ${file}`);
  }
  // Freezing bytes alone is insufficient: changing a platform, source SHA or
  // schema in the registry must not silently retire the installed client.
  for (const released of baselineRegistry.clients) {
    assert.deepEqual(registry.clients.find(client => client.file === released.file), released,
      `Released client registration changed: ${released.client}`);
  }
}
export function verifyFixtures(base = process.env.CI ? process.env.CONTRACT_BASE_REF : 'origin/main') {
  assert(base, 'Trusted base ref is required in CI');
  const baseline = {};
  // An exact SHA/ref is passed as an argument, never interpolated into a shell.
  const paths = execFileSync('git', ['ls-tree', '-r', '--name-only', base, '--', ...fixtureDirectories], {cwd: root, encoding: 'utf8'}).trim().split('\n').filter(Boolean);
  for (const path of paths) baseline[path] = hash(execFileSync('git', ['show', `${base}:${path}`], {cwd: root}));
  const registry = readJson(registryFile);
  const hasRetirementBaseline = execFileSync('git', ['ls-tree', '-r', '--name-only', base, '--', retirementPolicyFile], {cwd: root, encoding: 'utf8'}).trim();
  const retirementBaseline = hasRetirementBaseline
    ? JSON.parse(execFileSync('git', ['show', `${base}:${retirementPolicyFile}`], {cwd: root}))
    : {format: 1, retirements: []};
  validateRetirements(registry, readJson(retirementPolicyFile), retirementBaseline);
  const baselineRegistry = JSON.parse(execFileSync('git', ['show', `${base}:${registryFile}`], {cwd: root}));
  validateFixtures(registry, fixtureDirectories.flatMap(directory => existsSync(resolve(root, directory)) ? filesIn(directory).filter(f => f.endsWith('.json')) : []),
    file => readFileSync(resolve(root, file)), baseline, baselineRegistry);
  for (const client of registry.clients) {
    for (const file of clientFixtureFiles({clients: [client]})) {
      const {provenance} = readJson(file);
      if (!provenance) continue; // Historical fixture predates export provenance.
      const git = suffix => execFileSync('git', ['rev-parse', `${client.sourceCommit}${suffix}`], {cwd: root, encoding: 'utf8'}).trim();
      assert.equal(git('^{tree}'), provenance.sourceTree, `Wrong released source tree: ${file}`);
      if (provenance.kind === 'exported-from-released-source') {
        assert.equal(git(`:${provenance.exporter}`), provenance.exporterBlob, `Wrong released exporter: ${file}`);
      } else {
        assert.equal(provenance.kind, 'exported-with-historical-source-harness');
        assert.match(provenance.harness, /^tool\/firebase\/[a-z_]+_test\.dart$/);
        assert.equal(hash(readFileSync(resolve(root, provenance.harness))), provenance.harnessSha256,
          `Historical export harness changed: ${file}`);
        assert(Object.keys(provenance.sourceBlobs).length >= 4, 'Historical exporter needs source and lockfile provenance');
        for (const [source, blob] of Object.entries(provenance.sourceBlobs)) {
          assert(source === 'pubspec.lock' || /^lib\/[A-Za-z0-9_/.]+\.dart$/.test(source));
          assert(!source.includes('..'));
          assert.equal(git(`:${source}`), blob, `Wrong historical source blob: ${source}`);
        }
      }
    }
  }
}

// The current export must retain the wire shape understood by supported
// readers. Additional optional fields still need a preservation test; this
// check deliberately does not claim an old full-document writer retains them.
function requireReadableShape(released, current, path) {
  if (released === null) return;
  assert.notEqual(current, undefined, `Released wire field removed: ${path}`);
  if (Array.isArray(released)) {
    assert(Array.isArray(current), `Released wire type changed: ${path}`);
    assert.equal(current.length, released.length, `Released contract scenario removed: ${path}`);
    released.forEach((value, index) => requireReadableShape(value, current[index], `${path}/${index}`));
  } else if (typeof released === 'object') {
    assert(current && typeof current === 'object' && !Array.isArray(current), `Released wire type changed: ${path}`);
    for (const [key, value] of Object.entries(released)) requireReadableShape(value, current[key], `${path}/${key}`);
  } else {
    assert.equal(typeof current, typeof released, `Released wire type changed: ${path}`);
    if (/\/(schemaVersion|timingVersion|timerMode|durationKind|operation|split)$/.test(path)) {
      assert.equal(current, released, `Released wire protocol changed without a parallel contract: ${path}`);
    }
  }
}

export function validateCurrentContracts(registry, read) {
  const workout = JSON.parse(read('build/contracts/workout-save-current.json'));
  const app = JSON.parse(read('build/contracts/app-current.json'));
  for (const client of registry.clients) {
    const frozen = JSON.parse(read(client.file));
    if (client.capabilities) {
      // A pre-EMOM release can create only fixed timers. Match its actual
      // scenarios by name instead of manufacturing maximum/open timer support.
      for (const scenario of frozen.scenarios) {
        const current = workout.scenarios.find(candidate => candidate.name === scenario.name);
        requireReadableShape(scenario, current, `${client.client}/workout/${scenario.name}`);
      }
    } else {
      requireReadableShape(frozen.scenarios, workout.scenarios, `${client.client}/workout`);
    }
    if (client.appContract) {
      const releasedApp = JSON.parse(read(client.appContract.file));
      requireReadableShape(releasedApp.settings, app.settings, `${client.client}/settings`);
      requireReadableShape(releasedApp.playback, app.playback, `${client.client}/playback`);
    }
  }
}
