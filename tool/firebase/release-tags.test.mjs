import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {isReleaseTag, resolveReleaseTag, requireCurrentMain, requireNoRollback} from './release.mjs';

const repository = 'owner/cloud_board', sha = 'a'.repeat(40), previousSha = 'b'.repeat(40), tag = 'v1.2.3';
const source = {repository, sha, tag, ref: `refs/tags/${tag}`};
test('both development and production deployment tags cannot be moved or deleted', () => {
  const rules = JSON.parse(readFileSync(new URL('./release-tag-rules.json', import.meta.url), 'utf8'));
  assert.equal(rules.target, 'tag');
  assert.equal(rules.enforcement, 'active');
  assert.deepEqual(rules.conditions.ref_name, {include: ['refs/tags/v*', 'refs/tags/dev/v*'], exclude: []});
  assert.deepEqual(rules.bypass_actors, []);
  assert.deepEqual(rules.rules.map(rule => rule.type).sort(), ['deletion', 'update']);
});
const run = {id: 12, run_attempt: 1, head_sha: previousSha, head_branch: 'v1.2.2',
  head_repository: {full_name: repository}, event: 'push', status: 'completed', conclusion: 'failure'};
function requestWith({history = [], main = 'ahead', compare = 'ahead', queued = false} = {}) {
  return async path => {
    if (path.includes('/git/ref/')) return {object: {type: 'commit', sha}};
    if (path.endsWith(`${sha}...main`)) return {status: main, merge_base_commit: {sha}};
    if (path.includes('/compare/')) return {status: compare, merge_base_commit: {sha: previousSha}};
    if (path.includes('?branch=')) return {workflow_runs: history};
    if (path.includes('/runs?')) return {workflow_runs: queued ? [{...run, id: 13, status: 'queued'}, run] : [run]};
    if (path.includes('/jobs?')) return {jobs: [{name: 'firebase-production', conclusion: path.includes('/runs/13/') ? null : 'failure',
      steps: path.includes('/runs/13/') ? [] : [{name: 'Deploy account deletion functions and data rules', conclusion: 'failure'}]}]};
    throw new Error(`Unexpected request: ${path}`);
  };
}
test('production tag syntax is strict and annotated tags resolve to their commit', async () => {
  for (const value of ['v0.0.0', 'v1.2.3', 'v100.20.30']) assert(isReleaseTag(value));
  for (const value of ['', '1.2.3', 'v01.2.3', 'v1.2.3-qa', 'v1.2.3+4', 'v1.2.3/other']) assert(!isReleaseTag(value));
  const visited = [];
  assert.equal(await resolveReleaseTag({repository, tag, request: async path => {
    visited.push(path);
    return {object: path.includes('/git/ref/') ? {type: 'tag', sha: previousSha} : {type: 'commit', sha}};
  }}), sha);
  assert.equal(visited.length, 2);
});
test('a fixed release source survives main advancement but not unmerged source or a reused tag', async () => {
  await requireCurrentMain({...source, request: requestWith()});
  await assert.rejects(requireCurrentMain({...source, request: requestWith({main: 'diverged'})}), /included in main/);
  await assert.rejects(requireCurrentMain({...source, request: requestWith({history: [{...run, head_branch: tag}]})}), /reused/);
  await assert.rejects(requireCurrentMain({...source, request: async () => ({object: {type: 'commit', sha: previousSha}})}), /moved/);
});
test('production cannot go backwards after a failed or partial deployment attempt', async () => {
  await requireNoRollback({...source, scope: 'backend', request: requestWith()});
  for (const compare of ['behind', 'diverged']) {
    await assert.rejects(requireNoRollback({...source, scope: 'backend', request: requestWith({compare})}), /newer backend production attempt/);
  }
});
test('a newer tag waiting for the production lock does not invalidate the active release', async () => {
  await requireNoRollback({...source, scope: 'backend', request: requestWith({queued: true})});
});
