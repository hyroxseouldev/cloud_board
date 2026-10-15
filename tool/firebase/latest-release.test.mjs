import assert from 'node:assert/strict';
import test from 'node:test';
import {latestRelease} from './latest-release.mjs';
import {productionRuns} from './release-runs.mjs';
import {receiptFor} from './test-fixtures.mjs';
import {manifestHash} from './release.mjs';

const repository = 'owner/cloud_board', sha = 'a'.repeat(40);
const successful = {id: 12, run_attempt: 2, head_sha: sha, head_branch: 'main', head_repository: {full_name: repository}, event: 'push', status: 'completed', conclusion: 'success'};
const options = (runs, scope = 'full') => ({repository,
  request: async path => path.includes('/jobs?') ? {jobs: [{name: 'firebase-production', conclusion: 'success', steps: [{name: 'Deploy account deletion functions and data rules', conclusion: 'success'}]}]} : path.includes('/artifacts?') ? {artifacts: [{id: 1, name: 'firebase-release-12-2', expired: false}]} : {workflow_runs: runs},
  readArtifact: async () => {
    const receipt = receiptFor(); receipt.scope = scope; receipt.manifest.scope = scope;
    receipt.manifestHash = manifestHash(receipt.manifest); return receipt;
  },
});
test('monitor follows a verified rules/backend manual receipt without requiring Hosting', async () => {
  for (const scope of ['rules', 'backend', 'full']) {
    const result = await latestRelease(options([{...successful, event: 'workflow_dispatch'}], scope));
    assert.equal(result.receipt.scope, scope);
  }
});
test('monitor never hides failed or partial manual repairs behind an older successful push', async () => {
  for (const conclusion of ['failure', 'cancelled', 'skipped']) {
    await assert.rejects(latestRelease(options([successful, {...successful, id: 13, event: 'workflow_dispatch', conclusion}])), /refusing an older receipt/);
  }
});
test('any in-progress production attempt defers drift checks, including dispatch', async () => {
  assert.equal((await latestRelease(options([successful, {...successful, id: 13, event: 'workflow_dispatch', status: 'in_progress'}]))).status, 'deferred');
});
test('a later retry of an older workflow ID takes precedence and forks/PRs are excluded', () => {
  const retry = {...successful, id: 10, run_started_at: '2026-10-12T13:00:00Z', conclusion: 'failure'};
  const runs = productionRuns([{...successful, run_started_at: '2026-10-12T12:00:00Z'}, retry,
    {...successful, id: 90, event: 'pull_request'}, {...successful, id: 99, head_repository: {full_name: 'fork/repo'}}], repository);
  assert.equal(runs[0], retry);
  assert.equal(runs.length, 2);
});

test('web-only and no-op main runs do not replace or block the backend receipt', async () => {
  const base = options([successful]);
  for (const variant of ['web', 'none']) {
    const newer = {...successful, id: 13, conclusion: variant === 'web' ? 'failure' : 'success'};
    const request = async path => path.includes('/runs?') ? {workflow_runs: [successful, newer]}
      : path.includes('/runs/13/') && path.includes('/jobs?') ? {jobs: [{name: 'firebase-production',
        conclusion: variant === 'none' ? 'skipped' : 'failure', steps: [
          {name: 'Deploy account deletion functions and data rules', conclusion: 'skipped'},
          {name: 'Deploy data rules only', conclusion: 'skipped'},
          {name: 'Deploy to Firebase Hosting', conclusion: 'failure'},
        ]}]} : base.request(path);
    assert.equal((await latestRelease({...base, request})).run.id, 12);
    if (variant === 'web') await assert.rejects(latestRelease({...base, request, component: 'web'}), /refusing an older receipt/);
  }
});
test('planning may find last successful source without granting upload permission', async () => {
  const value = options([successful, {...successful, id: 13, conclusion: 'failure'}]);
  assert.equal((await latestRelease({...value, allowFailed: true})).run.id, 12);
  await assert.rejects(latestRelease(value), /refusing an older receipt/);
});

test('backend lookup continues past 100 web and documentation runs', async () => {
  const base = options([successful]);
  const pages = [];
  const firstPage = Array.from({length: 100}, (_, i) => ({...successful, id: 200 - i}));
  const request = async path => {
    if (path.includes('/runs?')) {
      pages.push(path);
      return {workflow_runs: path.endsWith('&page=2') ? [successful] : firstPage};
    }
    if (path.includes('/jobs?') && !path.includes('/runs/12/')) {
      return {jobs: [{name: 'firebase-production', conclusion: 'success', steps: [
        {name: 'Deploy account deletion functions and data rules', conclusion: 'skipped'},
        {name: 'Deploy data rules only', conclusion: 'skipped'},
        {name: 'Deploy to Firebase Hosting', conclusion: 'success'},
      ]}]};
    }
    return base.request(path);
  };
  assert.equal((await latestRelease({...base, request})).run.id, 12);
  assert.equal(pages.length, 2);
  assert(pages[0].endsWith('per_page=100'));
  assert(pages[1].endsWith('per_page=100&page=2'));
});
test('a partial backend failure on the next page still blocks an older success', async () => {
  const base = options([successful]);
  const request = async path => {
    if (path.includes('/runs?')) return {workflow_runs: path.endsWith('&page=2')
      ? [successful, {...successful, id: 13, conclusion: 'failure'}]
      : Array.from({length: 100}, (_, i) => ({...successful, id: 200 - i}))};
    if (path.includes('/jobs?') && !/\/runs\/(12|13)\//.test(path)) return {jobs: [{name: 'firebase-production', conclusion: 'skipped'}]};
    return base.request(path);
  };
  await assert.rejects(latestRelease({...base, request}), /refusing an older receipt/);
});
