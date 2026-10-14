import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, readdirSync, mkdirSync, realpathSync } from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import ts from '../functions-legacy/node_modules/typescript/lib/typescript.js';
import { parse } from '../functions-legacy/node_modules/dotenv/lib/main.js';

const root = fileURLToPath(new URL('../', import.meta.url));
const baselineFile = resolve(root, 'functions-legacy/migration-baseline.json');
export const baseline = JSON.parse(readFileSync(baselineFile, 'utf8'));
export const functionNames = baseline.functions.map(f => f.name).sort();
export const selector = functionNames.map(name => `functions:${baseline.codebase}:${name}`).join(',');
export const sha256 = value => createHash('sha256').update(value).digest('hex');
const json = file => JSON.parse(readFileSync(resolve(root, file), 'utf8'));
const sorted = object => Object.fromEntries(Object.entries(object).sort(([a], [b]) => a.localeCompare(b)));
const digest = object => sha256(JSON.stringify(sorted(object)));
const reserved = /^(?:FIREBASE_|GCLOUD_PROJECT$|GOOGLE_CLOUD_PROJECT$|FUNCTION_|EVENTARC_|K_|PORT$|LOG_EXECUTION_ID$)/;
const inventoryPath = 'build/legacy-auth/before.json';
const envPath = `functions-legacy/.env.${baseline.project}`;

export function declarationHashes(sourceText) {
  const source = ts.createSourceFile('index.js', sourceText, ts.ScriptTarget.ES2022, true, ts.ScriptKind.JS);
  const printer = ts.createPrinter({ removeComments: true });
  return Object.fromEntries(source.statements.filter(ts.isVariableStatement).flatMap(statement =>
    statement.declarationList.declarations.filter(d => functionNames.includes(d.name.getText(source)))
      .map(d => [d.name.getText(source), sha256(printer.printNode(ts.EmitHint.Unspecified, d, source))])));
}

export function sanitizeInventory(raw) {
  assert.equal(raw.status, 'success', 'Functions inventory failed');
  assert(Array.isArray(raw.result), 'Missing Functions inventory');
  return {
    format: 1, project: baseline.project, capturedAt: new Date().toISOString(),
    functions: raw.result.map(f => ({
      id: f.id, project: f.project, region: f.region, codebase: f.codebase,
      platform: f.platform, runtime: f.runtime, state: f.state,
      serviceAccount: f.serviceAccount, timeoutSeconds: f.timeoutSeconds,
      availableMemoryMb: f.availableMemoryMb, cpu: f.cpu,
      maxInstances: f.maxInstances, concurrency: f.concurrency,
      secretBindings: (f.secretEnvironmentVariables || []).map(s => ({
        key: s.key, secret: s.secret, version: s.version, projectId: s.projectId,
      })).sort((a, b) => a.key.localeCompare(b.key)),
      environmentVariableNames: Object.keys(f.environmentVariables || {}).sort(),
      // Values never leave memory. A digest detects drift without logging config.
      runtimeConfigSha256: digest(f.environmentVariables || {}),
      source: f.source, hash: f.hash,
      trigger: f.eventTrigger || f.schedule || (f.labels?.['deployment-callable'] === 'true' ? 'callable' : 'https'),
    })).sort((a, b) => `${a.region}/${a.id}`.localeCompare(`${b.region}/${b.id}`)),
  };
}

export function validateLive(inventory) {
  assert.equal(inventory.format, 1);
  assert.equal(inventory.project, baseline.project, 'Wrong inventory project');
  const managed = inventory.functions.filter(f => f.codebase === baseline.codebase);
  assert.deepEqual(managed.map(f => f.id).sort(), functionNames, 'Live legacy function set drifted; do not create/delete functions');
  for (const expected of baseline.functions) {
    const actual = managed.find(f => f.id === expected.name);
    for (const key of ['project', 'region', 'runtime', 'state', 'serviceAccount', 'timeoutSeconds', 'maxInstances', 'concurrency'])
      assert.equal(actual[key], key === 'project' ? baseline.project : expected[key], `Live ${expected.name} ${key} drift`);
    assert.deepEqual(actual.secretBindings.map(s => s.key).sort(), expected.secretNames, `Live ${expected.name} secret binding drift`);
    assert.deepEqual(actual.environmentVariableNames, expected.environmentVariableNames, `Live ${expected.name} config key drift`);
    assert.equal(actual.trigger, expected.name === 'cloudboardAuth' ? 'https' : 'callable', 'Unexpected legacy event/scheduled trigger');
  }
}

export function verifyAfter(before, after) {
  validateLive(before); validateLive(after);
  assert.deepEqual(after.functions.map(f => `${f.region}/${f.id}`), before.functions.map(f => `${f.region}/${f.id}`), 'Unexpected function creation/deletion');
  for (const previous of before.functions) {
    const current = after.functions.find(f => f.region === previous.region && f.id === previous.id);
    const stable = f => Object.fromEntries(Object.entries(f).filter(([key]) => !['source', 'hash'].includes(key)));
    assert.deepEqual(previous.codebase === baseline.codebase ? stable(current) : current,
      previous.codebase === baseline.codebase ? stable(previous) : previous,
      `Unexpected function, configuration, trigger or secret change: ${previous.id}`);
  }
}

export async function checkSource() {
  const config = json('firebase.legacy-auth.json');
  assert.deepEqual(Object.keys(config), ['functions'], 'Legacy deployment may only contain Functions');
  assert.equal(config.functions.length, 1);
  assert.equal(config.functions[0].source, 'functions-legacy');
  assert.equal(config.functions[0].codebase, baseline.codebase);
  assert.equal(config.functions[0].runtime, 'nodejs22');
  assert(config.functions[0].predeploy.some(command => command.includes('legacy-auth-release.mjs') && command.endsWith(' predeploy')), 'Missing predeploy guard');
  assert.equal(sha256(readFileSync(resolve(root, 'functions-legacy/package-lock.json'))), baseline.dependencyLockSha256, 'Production dependency lock changed');
  const modulePath = resolve(root, 'functions-legacy/lib/index.js');
  assert.equal(sha256(readFileSync(modulePath)), baseline.migratedIndexSha256, 'Migrated entrypoint changed beyond the reviewed export removal');
  assert.deepEqual(declarationHashes(readFileSync(modulePath, 'utf8')), baseline.exportDeclarationSha256, 'Active handlers differ from deployed source');
  for (const [file, hash] of Object.entries(baseline.supportingModuleSha256))
    assert.equal(sha256(readFileSync(resolve(root, 'functions-legacy', file))), hash, `Deployed support module changed: ${file}`);
  const functions = await import(pathToFileURL(modulePath));
  assert.deepEqual(Object.keys(functions).sort(), functionNames, 'Only the four currently ACTIVE functions may be exported');
  for (const expected of baseline.functions) {
    const endpoint = functions[expected.name].__endpoint;
    assert.equal(endpoint.platform, 'gcfv2');
    assert.deepEqual(endpoint.region, [baseline.region]);
    assert.equal(endpoint.timeoutSeconds, expected.timeoutSeconds);
    assert.equal(endpoint.maxInstances, expected.maxInstances);
    assert.deepEqual((endpoint.secretEnvironmentVariables || []).map(s => s.key).sort(), expected.secretNames);
    assert(expected.name === 'cloudboardAuth' ? endpoint.httpsTrigger : endpoint.callableTrigger);
    assert(!endpoint.eventTrigger && !endpoint.scheduleTrigger, 'Dormant trigger revival');
  }
  return digest({ index: sha256(readFileSync(modulePath)), ...baseline.supportingModuleSha256,
    lock: baseline.dependencyLockSha256, config: sha256(readFileSync(resolve(root, 'firebase.legacy-auth.json'))) });
}

function readLive() {
  try {
    return JSON.parse(execFileSync(process.env.FIREBASE_BIN || 'firebase', ['functions:list', '--project', baseline.project, '--json'],
      { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 32 * 1024 * 1024 }));
  } catch {
    // Child process failures can contain raw runtime env values; never print them.
    throw new Error('Read-only Firebase inventory failed; check CLI authentication/project access');
  }
}

async function readSecretVersions() {
  // Use GET directly: `firebase functions:secrets:get` may enable the API as a
  // side effect when disabled. Resolve the same installed CLI account, without
  // placing refresh/access tokens in arguments, environment or output.
  let token;
  try {
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      const require = createRequire(new URL('../functions-legacy/package.json', import.meta.url));
      const { GoogleAuth } = require('google-auth-library');
      token = await new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] }).getAccessToken();
    } else {
      const binary = execFileSync('which', [process.env.FIREBASE_BIN || 'firebase'], { encoding: 'utf8' }).trim();
      const require = createRequire(realpathSync(binary));
      const auth = require('../auth.js');
      const account = auth.getProjectDefaultAccount(root.replace(/\/$/, ''));
      token = (await auth.getAccessToken(account?.tokens?.refresh_token, ['https://www.googleapis.com/auth/cloud-platform'])).access_token;
    }
    assert(token);
  } catch { throw new Error('Read-only Secret metadata authentication failed; use the installed Firebase CLI or ADC'); }
  const names = [...new Set(baseline.functions.flatMap(f => f.secretNames))].sort();
  return Object.fromEntries(await Promise.all(names.map(async name => {
    const versions = [];
    let pageToken;
    do {
      const url = new URL(`https://secretmanager.googleapis.com/v1/projects/${baseline.project}/secrets/${name}/versions`);
      url.searchParams.set('pageSize', '100');
      if (pageToken) url.searchParams.set('pageToken', pageToken);
      const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
      assert(response.ok, `Secret metadata unavailable: ${name}`);
      const body = await response.json();
      versions.push(...(body.versions || []).map(v => ({ version: v.name.split('/').at(-1), state: v.state })));
      pageToken = body.nextPageToken;
    } while (pageToken);
    return [name, versions.sort((a, b) => Number(b.version) - Number(a.version))];
  })));
}

export function validateSecretVersions(inventory) {
  for (const fn of inventory.functions.filter(f => f.codebase === baseline.codebase)) {
    for (const binding of fn.secretBindings) {
      const latest = inventory.secretVersions?.[binding.key]?.[0];
      assert(latest?.state === 'ENABLED' && latest.version === binding.version,
        `Deploy would change the active secret version: ${binding.key}`);
    }
  }
}

function sharedRuntimeConfig(raw) {
  const maps = raw.result.filter(f => f.codebase === baseline.codebase).map(f =>
    sorted(Object.fromEntries(Object.entries(f.environmentVariables || {}).filter(([key]) => !reserved.test(key)))));
  assert.equal(maps.length, functionNames.length);
  for (const map of maps) assert.equal(digest(map), digest(maps[0]), 'Legacy functions have different runtime configuration; review per-function settings');
  assert(Object.keys(maps[0]).includes('BETTER_AUTH_URL'), 'Missing preserved runtime configuration');
  return maps[0];
}

export function validateReleaseEvidence(evidence, candidateDigest) {
  assert.equal(evidence.candidateDigest, candidateDigest, 'Regression evidence is for another candidate');
  assert.match(evidence.sourceSha || '', /^[a-f0-9]{40}$/);
  assert(evidence.appVersions?.released && evidence.appVersions?.candidate && evidence.tvVersion, 'Missing app/TV version evidence');
  for (const check of ['googleAppleLogin', 'phoneFreeActivation', 'legacyAccountEntitlement', 'pairDisplay', 'setDisplayState', 'threeTvClassLifecycle'])
    assert.equal(evidence.checks?.[check], 'passed', `Missing native regression: ${check}`);
  assert.equal(evidence.infrastructureReview, 'passed', 'Review Scheduler, Eventarc, Secret IAM and shared credentials before deploy');
}

async function main(command) {
  if (command === 'check') {
    const candidateDigest = await checkSource();
    console.log(JSON.stringify({ status: 'passed', candidateDigest, functions: functionNames })); return;
  }
  if (command === 'plan') {
    const candidateDigest = await checkSource();
    const raw = readLive(), inventory = sanitizeInventory(raw); validateLive(inventory);
    inventory.secretVersions = await readSecretVersions(); validateSecretVersions(inventory);
    const runtime = sharedRuntimeConfig(raw);
    const encoded = Object.entries(runtime).map(([key, value]) => `${key}=${JSON.stringify(value)}`).join('\n') + '\n';
    assert.equal(digest(parse(encoded)), digest(runtime), 'Runtime configuration requires manual safe encoding');
    mkdirSync(resolve(root, 'build/legacy-auth'), { recursive: true });
    writeFileSync(resolve(root, inventoryPath), JSON.stringify(inventory, null, 2) + '\n', { mode: 0o600 });
    writeFileSync(resolve(root, envPath), encoded, { mode: 0o600 });
    console.log(JSON.stringify({ status: 'review-required', candidateDigest, inventory: inventoryPath,
      runtimeConfiguration: envPath, selector, note: 'Read-only cloud operations; no deployment or credential deletion performed.' })); return;
  }
  if (command === 'predeploy') {
    assert.equal(process.env.GCLOUD_PROJECT, baseline.project, 'Wrong legacy deployment project');
    const candidateDigest = await checkSource();
    const evidence = process.env.CLOUDBOARD_LEGACY_RELEASE_EVIDENCE;
    assert(evidence, 'Set CLOUDBOARD_LEGACY_RELEASE_EVIDENCE to completed native regression evidence');
    validateReleaseEvidence(json(evidence), candidateDigest);
    assert.equal(json(evidence).sourceSha, execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(), 'Regression evidence SHA mismatch');
    const before = json(inventoryPath), raw = readLive(), current = sanitizeInventory(raw);
    validateLive(current);
    current.secretVersions = await readSecretVersions(); validateSecretVersions(current);
    assert.deepEqual(current.secretVersions, before.secretVersions, 'Secret versions changed after the reviewed plan');
    assert.deepEqual(current.functions, before.functions, 'Live functions changed after the reviewed plan');
    assert(Date.now() - Date.parse(before.capturedAt) < 30 * 60_000, 'Refresh the read-only deployment plan (30 minute limit)');
    assert.equal(digest(parse(readFileSync(resolve(root, envPath)))), digest(sharedRuntimeConfig(raw)), 'Runtime configuration drift');
    assert.deepEqual(readdirSync(resolve(root, 'functions-legacy')).filter(name => name.startsWith('.env')), [`.env.${baseline.project}`], 'Unexpected .env override');
    console.log('Legacy predeploy checks passed; only use the four-function selector from plan.'); return;
  }
  if (command === 'verify') {
    const after = sanitizeInventory(readLive()); verifyAfter(json(inventoryPath), after);
    after.secretVersions = await readSecretVersions(); validateSecretVersions(after);
    assert.deepEqual(after.secretVersions, json(inventoryPath).secretVersions, 'Unexpected secret version change');
    writeFileSync(resolve(root, 'build/legacy-auth/after.json'), JSON.stringify(after, null, 2) + '\n', { mode: 0o600 });
    console.log('Function inventory preserved; also recheck Scheduler/Eventarc/IAM and run app/TV smoke.'); return;
  }
  throw new Error('Usage: node tool/legacy-auth-release.mjs check|plan|predeploy|verify');
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main(process.argv[2]).catch(error => {
  // Assertions may include secrets in actual/expected; print only our fixed message.
  console.error(error.message.split('\n')[0]); process.exitCode = 1;
});
