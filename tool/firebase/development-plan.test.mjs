import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {developmentPlan, developmentChanges, isDevelopmentTag, compareDevelopmentTags,
  requireDevelopmentTag, requireCurrentDevelopment, pendingDevelopmentPlan} from './development-plan.mjs';

const sha = 'a'.repeat(40), base = 'b'.repeat(40), repository = 'owner/repo';
const tag = 'dev/v1.2.2-2';
const input = {eventName: 'push', ref: `refs/tags/${tag}`, sha};
const deployNames = ['Deploy stamped development web', 'Deploy development compatibility backend', 'Deploy development rules'];
const steps = deployNames.map(name => ({name, conclusion: 'success'}));
const previousRun = patch => ({id: 1, run_attempt: 1, head_sha: base, head_branch: 'dev/v1.2.2-1', event: 'push',
  created_at: '2026-10-15T00:00:00Z', head_repository: {full_name: repository}, ...patch});
const options = (patch = {}) => ({sha, ref: input.ref, version: '1.2.2', repository,
  request: async path => {
    if (path.includes('/git/ref/tags/')) return {object: {type: 'commit', sha}};
    if (path.endsWith(`/${sha}...main`)) return {status: 'ahead', merge_base_commit: {sha}, files: [{filename: 'lib/not-tagged.dart'}]};
    if (path.includes('/compare/')) return {status: 'ahead', merge_base_commit: {sha: base}};
    if (path.includes('/jobs?')) return {jobs: [{steps}]};
    return {workflow_runs: []};
  }, ...patch});

test('development tags are strict and compare version and sequence numerically', () => {
  for (const value of ['dev/v0.1.0-1', tag, 'dev/v1.2.2-10']) assert(isDevelopmentTag(value));
  for (const value of ['main', 'v1.2.2', 'dev/v1.2.2', 'dev/v1.2.2-0', 'dev/v1.2.2-01', 'dev/v01.2.2-1', 'dev/v1.2.2-1-extra']) assert(!isDevelopmentTag(value));
  assert.equal(compareDevelopmentTags('dev/v1.2.2-10', tag), 1);
  assert.equal(compareDevelopmentTags('dev/v1.3.0-1', 'dev/v1.2.2-100'), 1);
  assert.equal(compareDevelopmentTags(tag, tag), 0);
});

test('tagged development selects changed components, not documents or native-only files', () => {
  assert.deepEqual(developmentPlan({...input, changedFiles: ['lib/home.dart']}), {web: true, backend: false, rules: false});
  assert.deepEqual(developmentChanges(['functions/src/save.js', 'firestore.rules']), {web: false, backend: true, rules: true});
  for (const file of ['functions-legacy/src/index.ts', 'functions-legacy/package.json',
    'functions-legacy/package-lock.json', 'functions-legacy/tsconfig.json',
    'tool/firebase/prepare-development-display.mjs']) {
    assert.deepEqual(developmentChanges([file]), {web: false, backend: true, rules: false});
  }
  assert.deepEqual(developmentChanges(['AGENTS.md', 'ios/Runner/Info.plist']), {web: false, backend: false, rules: false});
  assert.deepEqual(developmentChanges(['firebase.development.json']), {web: true, backend: true, rules: true});
});

test('manual retry requires a development tag and an explicit isolated scope', () => {
  const eventName = 'workflow_dispatch';
  assert.deepEqual(developmentPlan({...input, eventName, event: {inputs: {scope: 'full'}}}), {web: true, backend: true, rules: true});
  assert.throws(() => developmentPlan({...input, eventName, event: {inputs: {scope: 'production'}}}));
  for (const ref of ['refs/heads/main', 'refs/heads/develop', 'refs/tags/v1.2.2', 'refs/tags/dev/v1.2.2-0']) {
    assert.throws(() => developmentPlan({...input, ref}));
    assert.throws(() => developmentPlan({...input, ref, eventName, event: {inputs: {scope: 'full'}}}));
  }
  assert.throws(() => developmentPlan({...input, eventName: 'pull_request'}));
});

test('fixed development tag survives newer untagged main changes but must match source and version', async () => {
  await requireDevelopmentTag(options());
  await assert.rejects(requireDevelopmentTag(options({version: '1.2.3'})), /pubspec version/);
  await assert.rejects(requireDevelopmentTag(options({ref: 'refs/heads/main'})), /Development tag/);
  const original = options().request;
  await assert.rejects(requireDevelopmentTag(options({request: async path => path.includes('/git/ref/tags/')
    ? {object: {type: 'commit', sha: base}} : original(path)})), /tag moved/);
  await assert.rejects(requireDevelopmentTag(options({request: async path => path.endsWith('...main')
    ? {status: 'diverged', merge_base_commit: {sha: base}} : original(path)})), /included in main/);
  await assert.rejects(requireDevelopmentTag(options({request: async path => path.includes('/runs?')
    ? {workflow_runs: [previousRun({head_branch: tag})]} : original(path)})), /reused/);
});

test('annotated development tags resolve to the fixed commit', async () => {
  const original = options().request;
  await requireDevelopmentTag(options({request: async path => path.includes('/git/ref/tags/')
    ? {object: {type: 'tag', sha: base}} : path.includes('/git/tags/')
      ? {object: {type: 'commit', sha}} : original(path)}));
});

test('older tagged sources and lower development sequences cannot replace newer deployments', async () => {
  const original = options().request;
  const withRun = run => options({request: async path => path.includes('/runs?') ? {workflow_runs: [run]} : original(path)});
  await requireCurrentDevelopment(withRun(previousRun()));
  await requireCurrentDevelopment(withRun(previousRun({head_branch: tag, head_sha: sha})));
  await assert.rejects(requireCurrentDevelopment(withRun(previousRun({head_branch: 'dev/v1.2.2-3', head_sha: sha}))), /newer development tag/);
  const stale = withRun(previousRun());
  await assert.rejects(requireCurrentDevelopment({...stale, request: async path => path.endsWith(`${base}...${sha}`)
    ? {status: 'behind', merge_base_commit: {sha}} : stale.request(path)}), /older source/);
});

test('failed and in-progress writes block older sources, while queued tags without writes do not', async () => {
  const original = options().request;
  const run = previousRun({head_branch: 'dev/v1.2.2-3'});
  for (const step of [{name: deployNames[1], conclusion: 'failure'}, {name: deployNames[1], status: 'in_progress'}]) {
    await assert.rejects(requireCurrentDevelopment(options({request: async path => path.includes('/runs?')
      ? {workflow_runs: [run]} : path.includes('/jobs?') ? {jobs: [{steps: [step]}]} : original(path)})), /newer development tag/);
  }
  await requireCurrentDevelopment(options({request: async path => path.includes('/runs?')
    ? {workflow_runs: [run]} : path.includes('/jobs?') ? {jobs: [{steps: []}]} : original(path)}));
});

test('tag planning retains component baselines from historical main and develop runs', async () => {
  for (const head_branch of ['main', 'develop', 'dev/v1.2.2-1']) {
    const result = await pendingDevelopmentPlan({repository, sha,
      request: async path => path.includes('/jobs?') ? {jobs: [{steps}]} : {workflow_runs: [previousRun({head_branch})]},
      diff: actualBase => {assert.equal(actualBase, base); return ['functions/src/save.js', 'lib/home.dart'];}});
    assert.deepEqual(result, {web: true, backend: true, rules: false});
  }
});

test('missing deployment evidence initializes components without relying on tag push before SHA', async () => {
  assert.deepEqual(await pendingDevelopmentPlan({repository, sha,
    request: async () => ({workflow_runs: []}), diff: () => {throw new Error('No invented baseline');}}),
  {web: true, backend: true, rules: true});
});

test('a reverted change reconciles in-flight, failed and hidden previous attempts', async () => {
  for (const variant of ['in-progress', 'failed', 'retry']) {
    const selected = steps.filter(step => step.name !== deployNames[1]);
    if (variant !== 'retry') selected.push({name: deployNames[1],
      status: variant === 'in-progress' ? 'in_progress' : 'completed', conclusion: variant === 'failed' ? 'failure' : null});
    const result = await pendingDevelopmentPlan({repository, sha,
      request: async path => path.includes('/jobs?') ? {jobs: [{steps: selected}]} :
        {workflow_runs: [previousRun({run_attempt: variant === 'retry' ? 2 : 1})]}, diff: () => []});
    assert.deepEqual(result, {web: false, backend: true, rules: false}, variant);
  }
});

test('history stops after component evidence is found and tag reuse reads only that tag', async () => {
  const calls = [];
  const page = Array.from({length: 100}, (_, i) => previousRun({id: 100 + i}));
  const original = options().request;
  const request = async path => {
    calls.push(path);
    if (path.includes('/runs?branch=')) {
      assert(path.includes(`branch=${encodeURIComponent(tag)}&`));
      return {workflow_runs: []};
    }
    if (path.includes('/runs?')) {
      assert(path.endsWith('page=1'), 'No second page is needed once all component baselines exist');
      return {workflow_runs: page};
    }
    return original(path);
  };
  const baseline = await requireCurrentDevelopment(options({request}));
  const count = calls.length;
  assert.deepEqual(await pendingDevelopmentPlan({repository, sha, request, baseline, diff: () => []}),
    {web: false, backend: false, rules: false});
  assert.equal(calls.length, count, 'Planning reuses the already checked component baselines');
  assert.equal(calls.filter(path => path.includes('/jobs?')).length, 1);
  assert.equal(calls.filter(path => path.includes('/runs?')).length, 2);
});

test('late old retries without writes cannot hide newer actual deployment evidence', async () => {
  const original = options().request;
  const oldRetry = previousRun({id: 1, run_attempt: 2, run_started_at: '2026-10-16T00:00:00Z'});
  const newer = previousRun({id: 2, head_branch: 'dev/v1.2.2-3', created_at: '2026-10-15T12:00:00Z'});
  // Even if a late retry is returned first, its uncertainty cannot terminate
  // the scan before the newer successful write is examined.
  const request = async path => path.includes('/runs?branch=') ? {workflow_runs: []}
    : path.includes('/runs?') ? {workflow_runs: [oldRetry, newer]}
      : path.includes('/runs/1/attempts/') ? {jobs: [{steps: []}]} : original(path);
  await assert.rejects(requireCurrentDevelopment(options({request})), /newer development tag/);
  assert.deepEqual(await pendingDevelopmentPlan({repository, sha, request, diff: () => []}),
    {web: true, backend: true, rules: true});
});

test('workflow has no main trigger and pins build/deploy checkouts to the plan source', () => {
  const workflow = readFileSync('.github/workflows/firebase-development.yml', 'utf8');
  const triggers = workflow.match(/^on:\n([\s\S]*?)(?=^\S)/m)[1];
  assert.match(triggers, /tags: \['dev\/v/);
  assert.doesNotMatch(triggers, /branches:|paths:|main/);
  assert.match(workflow, /if: startsWith\(github.ref, 'refs\/tags\/dev\/v'\)/);
  assert.equal((workflow.match(/ref: \$\{\{ needs.plan.outputs.source_sha \}\}/g) || []).length, 3);
  assert.equal((workflow.match(/      actions: read/g) || []).length, 2);
  assert.equal((workflow.match(/DEVELOPMENT_SOURCE_SHA:/g) || []).length, 2);
  assert.match(workflow, /name: Deploy stamped development web\n        run: \|\n          node tool\/firebase\/development-plan.mjs current/);
});
