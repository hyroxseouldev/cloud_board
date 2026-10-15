import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {releaseStartPlan, startRelease} from './start_release.mjs';

const sha = 'a'.repeat(40), mainSha = 'b'.repeat(40), repository = 'owner/repo';
const options = {tag: 'v1.2.3', scope: 'full', skipCi: false, reason: '', sourceSha: sha,
  ref: 'refs/heads/main', eventName: 'workflow_dispatch', repository, actor: 'operator', runId: '123', runAttempt: '1',
  runGit: (...args) => args[0] === 'rev-parse' ? sha : 'name: cloud_board\nversion: 1.2.3+7\n'};

function fixture(overrides = {}) {
  const calls = [], records = [];
  return {calls, records, record: receipt => records.push(structuredClone(receipt)), request: async (path, request = {}) => {
    calls.push({path, ...request});
    if (overrides[path]) return overrides[path](request);
    if (path.endsWith('/git/ref/heads/main')) return {status: 200, data: {object: {sha: mainSha}}};
    if (path.includes('/compare/')) return {status: 200, data: {status: 'ahead'}};
    if (path.includes('/git/ref/tags/')) return {status: 404};
    if (path.includes('/runs?')) return {status: 200, data: {total_count: 0, workflow_runs: []}};
    if (path.endsWith('/git/refs')) return {status: 201, data: {ref: 'refs/tags/v1.2.3', object: {sha}}};
    if (path.endsWith('/dispatches')) return {status: 204};
    throw new Error(`Unexpected request ${path}`);
  }};
}

test('starts one fixed-SHA release with required CI or an explicitly reasoned skip', async () => {
  for (const skipCi of [false, true]) {
    const f = fixture();
    const plan = releaseStartPlan({...options, skipCi, reason: skipCi ? '  Restore service  ' : ''});
    const receipt = await startRelease(plan, f);
    const mutations = f.calls.filter(call => call.method);
    assert.deepEqual(mutations, [
      {path: `/repos/${repository}/git/refs`, method: 'POST', body: {ref: 'refs/tags/v1.2.3', sha}},
      {path: `/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/dispatches`, method: 'POST',
        body: {ref: 'v1.2.3', inputs: {confirm_sha: sha, scope: 'full', skip_ci: String(skipCi), skip_ci_reason: skipCi ? 'Restore service' : ''}}},
    ]);
    assert.equal(receipt.sourceSha, sha); // Current main advanced; never silently switch to it.
    assert.equal(receipt.dispatchStatus, 'accepted');
    assert.equal(receipt.actor, 'operator');
    assert.equal(receipt.runId, '123');
    assert.deepEqual(f.records.map(record => record.dispatchStatus), ['not_requested', 'requested', 'accepted']);
  }
});

test('existing tag is rejected even when it already points to the requested source', async () => {
  const f = fixture({[`/repos/${repository}/git/ref/tags/v1.2.3`]: () => ({status: 200, data: {object: {sha}}})});
  await assert.rejects(startRelease(releaseStartPlan(options), f), /tag already exists/);
  assert(!f.calls.some(call => call.method));
});

test('missing tag with previous workflow history cannot be recreated', async () => {
  const f = fixture({[`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?branch=v1.2.3&per_page=1`]:
    () => ({status: 200, data: {total_count: 1, workflow_runs: [{id: 9}]}})});
  await assert.rejects(startRelease(releaseStartPlan(options), f), /has workflow history/);
  assert(!f.calls.some(call => call.method));
});

test('dispatch failure or timeout keeps the tag and never retries or deletes it', async () => {
  for (const failure of [() => ({status: 403}), () => {throw new Error('timeout');}]) {
    const f = fixture({[`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/dispatches`]: failure});
    await assert.rejects(startRelease(releaseStartPlan(options), f), error =>
      error.message.includes(`Tag v1.2.3 remains at ${sha}`) && error.message.includes('Check Actions') &&
      error.message.includes('Do not delete or move the tag'));
    assert.equal(f.calls.filter(call => call.path.endsWith('/dispatches')).length, 1);
    assert.equal(f.calls.filter(call => call.method).length, 2);
    assert(!f.calls.some(call => ['DELETE', 'PATCH'].includes(call.method)));
    assert.equal(f.records.at(-1).tagCreated, true);
    assert.equal(f.records.at(-1).dispatchStatus, 'failed_or_unconfirmed');
  }
});

test('a concurrent tag creation failure cannot dispatch a second release', async () => {
  const f = fixture({[`/repos/${repository}/git/refs`]: () => ({status: 422})});
  await assert.rejects(startRelease(releaseStartPlan(options), f), /Tag creation failed/);
  assert(!f.calls.some(call => call.path.endsWith('/dispatches')));
});

test('invalid source, scope, version and reason fail before any network mutation', () => {
  for (const patch of [
    {scope: 'verify'}, {scope: 'qa'}, {scope: 'auto'}, {tag: 'v1.2.4'}, {tag: 'v1.2.3/unsafe'},
    {ref: 'refs/heads/develop'}, {ref: 'refs/tags/v1.2.3'}, {eventName: 'push'},
    {skipCi: 'true'}, {skipCi: true, reason: '   '}, {reason: 'x'.repeat(2001)},
    {sourceSha: 'wrong'}, {actor: ''}, {runGit: () => mainSha},
  ]) assert.throws(() => releaseStartPlan({...options, ...patch}));
});

test('non-ancestor sources and uncertain preflight reads fail closed', async () => {
  for (const overrides of [
    {[`/repos/${repository}/compare/${sha}...${mainSha}`]: () => ({status: 200, data: {status: 'diverged'}})},
    {[`/repos/${repository}/git/ref/heads/main`]: () => ({status: 403})},
    {[`/repos/${repository}/git/ref/tags/v1.2.3`]: () => ({status: 500})},
    {[`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?branch=v1.2.3&per_page=1`]: () => ({status: 403})},
  ]) {
    const f = fixture(overrides);
    await assert.rejects(startRelease(releaseStartPlan(options), f));
    assert(!f.calls.some(call => call.method));
  }
});

test('workflow pins source and uses GITHUB_TOKEN so tag creation does not start duplicate push CI', () => {
  const yaml = readFileSync(new URL('../../.github/workflows/start-production-release.yml', import.meta.url), 'utf8');
  assert.match(yaml, /workflow_dispatch:/);
  assert.doesNotMatch(yaml, /^  (push|workflow_run):/m);
  assert.match(yaml, /ref: \$\{\{ github\.sha \}\}/);
  assert.match(yaml, /GITHUB_TOKEN: \$\{\{ github\.token \}\}/);
  assert.match(yaml, /contents: write/);
  assert.match(yaml, /actions: write/);
  assert.match(yaml, /cancel-in-progress: false/);
  assert.doesNotMatch(yaml, /secrets\./);
});
