import assert from 'node:assert/strict';
import test from 'node:test';
import {developmentPlan, requireDevelopmentMain, pendingDevelopmentPlan} from './development-plan.mjs';

const input = {eventName: 'push', ref: 'refs/heads/main', sha: 'a'.repeat(40)};
test('main deploys only changed development components, not documents or native-only files', () => {
  assert.deepEqual(developmentPlan({...input, changedFiles: ['lib/home.dart']}), {web: true, backend: false, rules: false});
  assert.deepEqual(developmentPlan({...input, changedFiles: ['functions/src/save.js', 'firestore.rules']}), {web: false, backend: true, rules: true});
  assert.deepEqual(developmentPlan({...input, changedFiles: ['AGENTS.md', 'ios/Runner/Info.plist']}), {web: false, backend: false, rules: false});
  assert.deepEqual(developmentPlan({...input, changedFiles: ['firebase.development.json']}), {web: true, backend: true, rules: true});
});
test('manual retry requires main and an explicit isolated scope', () => {
  const eventName = 'workflow_dispatch';
  assert.deepEqual(developmentPlan({...input, eventName, event: {inputs: {scope: 'full'}}}), {web: true, backend: true, rules: true});
  assert.throws(() => developmentPlan({...input, eventName, event: {inputs: {scope: 'production'}}}));
  for (const ref of ['refs/heads/develop', 'refs/tags/v1.2.0']) assert.throws(() => developmentPlan({...input, ref}));
  assert.throws(() => developmentPlan({...input, eventName: 'pull_request'}));
});
test('an older queued development deploy cannot overwrite newer main', async () => {
  await requireDevelopmentMain({sha: input.sha, repository: 'owner/repo', request: async () => ({object: {sha: input.sha}})});
  await assert.rejects(requireDevelopmentMain({sha: input.sha, repository: 'owner/repo', request: async () => ({object: {sha: 'b'.repeat(40)}})}), /Newer main/);
});
test('documentation-only main advances do not strand the building app', async () => {
  const options = {sha: input.sha, repository: 'owner/repo', request: async path => path.includes('/compare/')
    ? {status: 'ahead', merge_base_commit: {sha: input.sha}, files: [{filename: 'docs/readme.md'}]}
    : {object: {sha: 'b'.repeat(40)}}};
  await requireDevelopmentMain(options);
  await assert.rejects(requireDevelopmentMain({...options, request: async path => path.includes('/compare/')
    ? {status: 'ahead', merge_base_commit: {sha: input.sha}, files: [{filename: 'functions/src/save.js'}]}
    : {object: {sha: 'b'.repeat(40)}}}), /Newer main/);
});
test('a later web push carries the server changes from a superseded failed deployment', async () => {
  const base = 'b'.repeat(40);
  const run = {id: 1, run_attempt: 1, head_sha: base, head_branch: 'main', event: 'push',
    created_at: '2026-10-15T00:00:00Z', head_repository: {full_name: 'owner/repo'}};
  const steps = ['Deploy stamped development web', 'Deploy development compatibility backend', 'Deploy development rules']
    .map(name => ({name, conclusion: 'success'}));
  const result = await pendingDevelopmentPlan({repository: 'owner/repo', sha: input.sha,
    request: async path => path.includes('/jobs?') ? {jobs: [{steps}]} : {workflow_runs: [run]},
    diff: actualBase => {assert.equal(actualBase, base); return ['functions/src/save.js', 'lib/home.dart'];}});
  assert.deepEqual(result, {web: true, backend: true, rules: false});
});
test('missing development deployment evidence initializes each component conservatively', async () => {
  assert.deepEqual(await pendingDevelopmentPlan({repository: 'owner/repo', sha: input.sha,
    request: async () => ({workflow_runs: []}), diff: () => {throw new Error('No invented baseline');}}),
  {web: true, backend: true, rules: true});
});
test('a reverted change still reconciles an in-flight or hidden previous deployment attempt', async () => {
  const run = {id: 2, run_attempt: 1, head_sha: 'b'.repeat(40), head_branch: 'main', event: 'push',
    created_at: '2026-10-15T00:00:00Z', head_repository: {full_name: 'owner/repo'}};
  for (const variant of ['in-progress', 'failed', 'retry']) {
    const steps = ['Deploy stamped development web', 'Deploy development rules'].map(name => ({name, conclusion: 'success'}));
    if (variant !== 'retry') steps.push({name: 'Deploy development compatibility backend',
      status: variant === 'in-progress' ? 'in_progress' : 'completed', conclusion: variant === 'failed' ? 'failure' : null});
    const result = await pendingDevelopmentPlan({repository: 'owner/repo', sha: input.sha,
      request: async path => path.includes('/jobs?') ? {jobs: [{steps}]} :
        {workflow_runs: [{...run, run_attempt: variant === 'retry' ? 2 : 1}]}, diff: () => []});
    assert.deepEqual(result, {web: false, backend: true, rules: false}, variant);
  }
});
