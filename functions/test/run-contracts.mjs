import assert from 'node:assert/strict';
import {createWriteStream, readFileSync, mkdirSync, rmSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {execFileSync} from 'node:child_process';
import {gzipSync} from 'node:zlib';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {ref, set} from 'firebase/database';
import {root, readJson, hashFile, filesIn, writeJson, run, emulatorAddress, requireDemo, jsonRequest} from '../../tool/firebase/common.mjs';

const manifest = readJson('tool/firebase/contract-suites.json');
const output = 'build/firebase-contracts';
const endpoints = {
  firestore: emulatorAddress(process.env.FIRESTORE_EMULATOR_HOST),
  database: emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST),
  storage: emulatorAddress(process.env.FIREBASE_STORAGE_EMULATOR_HOST),
  auth: emulatorAddress(process.env.FIREBASE_AUTH_EMULATOR_HOST),
};
requireDemo(process.env.GCLOUD_PROJECT);
assert.equal(manifest.format, 1);
assert.equal(new Set(manifest.suites.map(s => s.id)).size, manifest.suites.length);
const found = filesIn('functions/test').filter(f => /(?:^|\/)(?:.*-)?emulator\.mjs$/.test(f));
assert.deepEqual(manifest.suites.map(s => s.file).filter(f => f.startsWith('functions/test/')).sort(), found,
  'Every emulator suite must be registered');
rmSync(resolve(root, output), {recursive: true, force: true});
mkdirSync(resolve(root, output), {recursive: true});
const report = {format: 1, sha: process.env.GITHUB_SHA || execFileSync('git', ['rev-parse', 'HEAD'], {encoding: 'utf8'}).trim(),
  runId: process.env.GITHUB_RUN_ID || 'local', attempt: process.env.GITHUB_RUN_ATTEMPT || '1',
  manifestHash: hashFile('tool/firebase/contract-suites.json'), startedAt: new Date().toISOString(), status: 'running', suites: []};
const persist = () => writeJson(`${output}/report.json`, report);
persist();

async function reset(suite) {
  const projectId = requireDemo(suite.project);
  const env = await initializeTestEnvironment({projectId,
    firestore: {...endpoints.firestore, rules: readFileSync('firestore.rules', 'utf8')},
    database: {...endpoints.database, rules: readFileSync('database.rules.json', 'utf8')},
    storage: {...endpoints.storage, rules: readFileSync('storage.rules', 'utf8')},
  });
  try {
    await env.clearFirestore(); await env.clearDatabase();
    // Account deletion uses the real default-rtdb naming convention.
    await env.withSecurityRulesDisabled(c => set(ref(c.database(`https://${projectId}-default-rtdb.asia-southeast1.firebasedatabase.app`)), null));
    await env.clearStorage();
    await jsonRequest(`http://${endpoints.auth.host}:${endpoints.auth.port}/emulator/v1/projects/${projectId}/accounts`, {method: 'DELETE'});
  } finally { await env.cleanup(); }
}
async function coverage(suite) {
  const saved = [];
  for (const service of suite.coverage) {
    const address = endpoints[service];
    const ns = suite.databaseNamespace || suite.project;
    for (const format of ['json', 'html']) {
      const path = service === 'firestore'
        ? `/emulator/v1/projects/${suite.project}:ruleCoverage${format === 'html' ? '.html' : ''}`
        : `/.inspect/coverage${format === 'json' ? '.json' : ''}?ns=${ns}`;
      const response = await fetch(`http://${address.host}:${address.port}${path}`, {signal: AbortSignal.timeout(15_000)});
      assert(response.ok, `Missing ${service} coverage (${response.status})`);
      const bytes = await response.text();
      if (format === 'json') assert(JSON.parse(bytes) && bytes.length > 2, 'Empty coverage');
      else assert(bytes.length > 0, 'Empty coverage HTML');
      const name = `${output}/${suite.id}-${service}.${format}.gz`;
      writeFileSync(name, gzipSync(bytes));
      saved.push({file: name, sha256: hashFile(name)});
    }
  }
  return saved;
}

for (const suite of manifest.suites) {
  const started = Date.now();
  const item = {id: suite.id, file: suite.file, project: suite.project, status: 'running', coverage: []};
  report.suites.push(item); persist();
  console.log(`START ${suite.id}`);
  const log = createWriteStream(`${output}/${suite.id}.log`);
  try {
    await reset(suite);
    await run(process.execPath, [suite.file], {
      env: {...process.env, GCLOUD_PROJECT: suite.project,
        FIREBASE_CONFIG: JSON.stringify({projectId: suite.project, storageBucket: `${suite.project}.firebasestorage.app`})},
      timeoutMs: manifest.timeoutSeconds * 1000, log,
    });
    item.status = 'success';
  } catch (error) { item.status = 'failure'; item.error = error.message; }
  finally {
    await new Promise(resolveEnd => log.end(resolveEnd));
    try { item.coverage = await coverage(suite); }
    catch (error) { item.status = 'failure'; item.coverageError = error.message; }
    item.log = {file: `${output}/${suite.id}.log`, sha256: hashFile(`${output}/${suite.id}.log`)};
    item.durationMs = Date.now() - started;
    console.log(`${item.status.toUpperCase()} ${suite.id} (${item.durationMs}ms)`);
    if (item.status !== 'success') console.log(readFileSync(item.log.file, 'utf8').slice(-5000));
    persist();
  }
}
report.status = report.suites.every(s => s.status === 'success') ? 'success' : 'failure';
report.finishedAt = new Date().toISOString(); persist();
process.exitCode = report.status === 'success' ? 0 : 1;
