import assert from 'node:assert/strict';
import test from 'node:test';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, cpSync, mkdirSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, dirname, resolve} from 'node:path';
import {requireBackend} from './release_backend_gate.mjs';
import {receiptFor} from './firebase/test-fixtures.mjs';
import {manifestHash, backendFingerprint, functionsFingerprint} from './firebase/release.mjs';
const sha = 'a'.repeat(40), repository = 'owner/cloud_board';
const deployed = 'b'.repeat(40);
const run = {id: 12, run_attempt: 2, head_sha: deployed, head_branch: 'main', head_repository: {full_name: repository}, event: 'push', status: 'completed', conclusion: 'success'};
function options(extras = {}) {
  return {repository, sha, fingerprint: backendFingerprint(), candidateFunctionsFingerprint: functionsFingerprint(), request: async path => path.includes('/compare/') ? {status: 'ahead', merge_base_commit: {sha}}
    : path.includes('/jobs?') ? {jobs: [{name: 'firebase-production', conclusion: 'success', steps: [{name: 'Deploy account deletion functions and data rules', conclusion: 'success'}]}]}
    : path.includes('/artifacts?') ? {artifacts: [{id: 1, name: 'firebase-release-12-2', expired: false}]}
    : {workflow_runs: [run]},
    readArtifact: async () => receiptFor({sha: deployed, runId: '12', attempt: '2'}), ...extras};
}
test('app-only upload reuses compatible deployed backend from a different source SHA', async () => {
  assert.equal((await requireBackend(options())).id, 12);
});
test('backend-only receipt authorizes an app without requiring Hosting', async () => {
  const base = options();
  assert.equal((await requireBackend({...base, readArtifact: async () => {
    const receipt = await base.readArtifact(); receipt.scope = 'backend'; receipt.manifest.scope = 'backend';
    receipt.manifestHash = manifestHash(receipt.manifest); return receipt;
  }})).id, 12);
});
test('new server dependency blocks even fast QA', async () => {
  await assert.rejects(requireBackend(options({mode: 'qa', fingerprint: '0'.repeat(64)})), /different backend/);
});
test('a fixed source remains trusted after main advances; unrelated source is denied', async () => {
  const base = options();
  await assert.rejects(requireBackend({...base, request: async path => path.includes('/compare/')
    ? {status: 'diverged', merge_base_commit: {sha: deployed}} : base.request(path)}), /trusted/);
});
test('QA permits integrated develop source while release requires main ancestry', async () => {
  const base = options();
  const request = async path => path.includes('/compare/') ? path.endsWith('...develop')
    ? {status: 'ahead', merge_base_commit: {sha}} : {status: 'diverged', merge_base_commit: {sha: deployed}} : base.request(path);
  assert.equal((await requireBackend({...base, request, mode: 'qa'})).id, 12);
  await assert.rejects(requireBackend({...base, request, mode: 'release'}), /trusted/);
});
test('failed or partial newer server deployment cannot fall back to older receipt', async () => {
  const base = options();
  for (const conclusion of ['failure', 'cancelled', 'skipped']) await assert.rejects(requireBackend({...base,
    request: async path => path.includes('/runs?') ? {workflow_runs: [run, {...run, id: 13, conclusion}]} : base.request(path)}), /refusing an older receipt/);
});
test('pending backend fails immediately rather than polling for a full release', async () => {
  const base = options();
  await assert.rejects(requireBackend({...base, request: async path => path.includes('/runs?')
    ? {workflow_runs: [{...run, status: 'in_progress'}]} : base.request(path)}), /in progress/);
});
test('missing, expired, wrong-attempt or failed-smoke evidence rejects upload', async () => {
  const base = options();
  await assert.rejects(requireBackend({...base, request: async path => path.includes('/artifacts?') ? {artifacts: []} : base.request(path)}));
  await assert.rejects(requireBackend({...base, readArtifact: async () => receiptFor({sha: deployed, runId: '12', attempt: '1'})}));
  await assert.rejects(requireBackend({...base, readArtifact: async () => {const r = await base.readArtifact(); r.smoke.cleanup = 'failure'; return r;}}));
});

test('rules-only repair cannot attest to Functions that it will not deploy', async () => {
  const base = options();
  assert.equal((await requireBackend({...base, functionsOnly: true})).id, 12);
  await assert.rejects(requireBackend({...base, functionsOnly: true, readArtifact: async () => {
    const receipt = await base.readArtifact(); receipt.manifest.functionsFingerprint = '0'.repeat(64);
    receipt.manifestHash = manifestHash(receipt.manifest); return receipt;
  }}), /undeployed Functions/);
});

test('trusted control tooling checks the selected app source, not its own checkout', () => {
  const directory = mkdtempSync(join(tmpdir(), 'backend-selected-source-'));
  const app = join(directory, 'app'); mkdirSync(app);
  const runGit = args => execFileSync('git', args, {cwd: app, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
  try {
    for (const path of ['firebase.json', 'firestore.rules', 'database.rules.json', 'storage.rules', 'firestore.indexes.json',
      'functions/package.json', 'functions/package-lock.json', 'functions/src', 'functions/certificates']) {
      mkdirSync(dirname(join(app, path)), {recursive: true}); cpSync(resolve(path), join(app, path), {recursive: true});
    }
    writeFileSync(join(app, 'functions/src/new-api.js'), 'export const requiresNewServer = true;\n');
    runGit(['init', '-q']); runGit(['add', '.']);
    // Isolated fixture history only; the product repository is never committed.
    runGit(['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'candidate']);
    const source = runGit(['rev-parse', 'HEAD']);
    const receipt = receiptFor({sha: deployed, runId: '12', attempt: '2'});
    const script = `
      import assert from 'node:assert/strict';
      import {requireBackend} from ${JSON.stringify(new URL('./release_backend_gate.mjs', import.meta.url).href)};
      const sha = ${JSON.stringify(source)}, receipt = ${JSON.stringify(receipt)}, run = ${JSON.stringify(run)};
      await assert.rejects(requireBackend({repository: ${JSON.stringify(repository)}, sha,
        request: async path => path.includes('/compare/') ? {status: 'identical', merge_base_commit: {sha}}
          : path.includes('/jobs?') ? {jobs: [{name: 'firebase-production', conclusion: 'success', steps: [{name: 'Deploy account deletion functions and data rules', conclusion: 'success'}]}]}
          : path.includes('/artifacts?') ? {artifacts: [{id: 1, name: 'firebase-release-12-2', expired: false}]}
          : {workflow_runs: [run]}, readArtifact: async () => receipt}), /different backend/);
    `;
    execFileSync(process.execPath, ['--input-type=module', '-e', script], {cwd: app, stdio: ['ignore', 'pipe', 'pipe']});
  } finally { rmSync(directory, {recursive: true, force: true}); }
});
