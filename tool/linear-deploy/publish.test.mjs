import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { pipelines, trustedRun, latestRuns, deploymentStatus, updateId, renderUpdate, upsertUpdate, requestJson, changeRange } from './publish.mjs';

const repository = 'hyroxseouldev/cloud_board';
const sha = 'a'.repeat(40);
const projectId = '00a512bb-598c-4967-b435-e78cadc4e8f2';
const run = (extra = {}) => ({ id: 1, run_number: 25, run_attempt: 1, head_sha: sha,
  head_branch: 'main', head_repository: { full_name: repository }, event: 'push',
  path: pipelines[0].path, status: 'completed', conclusion: 'success', ...extra });
const jobs = (pipeline, conclusion) => [{ conclusion: 'success', steps: [{ name: pipeline.step, conclusion }] }];

test('only own main push/manual deployment runs qualify', () => {
  assert.equal(trustedRun(run(), repository), true);
  for (const extra of [{ head_branch: 'develop' }, { event: 'pull_request' },
    { head_repository: { full_name: 'someone/fork' } }, { path: '.github/workflows/untrusted.yml' }]) {
    assert.equal(trustedRun(run(extra), repository), false);
  }
});

test('latest attempt/run wins; other commits and PR runs never contaminate results', () => {
  const runs = latestRuns([run(), run({run_attempt: 2, conclusion: 'failure'}),
    run({id: 5, event: 'pull_request'}), run({id: 6, head_sha: 'b'.repeat(40)})], sha, repository);
  assert.equal(runs[0].run_attempt, 2);
  assert.equal(runs[0].conclusion, 'failure');
  assert.equal(runs[1], null);
  assert.equal(latestRuns([run(), run({id: 2, status: 'queued', conclusion: null})], sha, repository)[0].id, 2);
});

test('step success is required; skipped upload is not deployment success', () => {
  for (const p of pipelines) {
    assert.equal(deploymentStatus(p, run(), jobs(p, 'success')), p.success);
    assert.match(deploymentStatus(p, run(), jobs(p, 'skipped')), /건너뜀/);
    assert.match(deploymentStatus(p, run(), [{conclusion: 'success', steps: []}]), /확인 필요/);
    assert.match(deploymentStatus(p, run({conclusion: 'failure'}), jobs(p, 'failure')), /실패/);
    assert.match(deploymentStatus(p, run({conclusion: 'cancelled'}), []), /취소/);
    assert.match(deploymentStatus(p, run({conclusion: 'timed_out'}), []), /실패/);
    assert.match(deploymentStatus(p, run({status: 'in_progress', conclusion: null}), []), /진행 중/);
    assert.match(deploymentStatus(p, run({status: 'queued', conclusion: null}), []), /대기 중/);
    assert.match(deploymentStatus(p, null), /기록 없음/);
    assert.match(deploymentStatus(p, run({conclusion: 'failure'}), jobs(p, 'success')), /후속 작업/);
  }
});

test('stable project/repo/SHA identity across platforms and retries', () => {
  assert.equal(updateId(projectId, repository, sha), updateId(projectId, repository, sha));
  assert.notEqual(updateId(projectId, repository, sha), updateId(projectId, repository, 'b'.repeat(40)));
  assert.notEqual(updateId(projectId, repository, sha), updateId('other', repository, sha));
  assert.match(updateId(projectId, repository, sha), /^[a-f0-9-]{14}5[a-f0-9-]{21}$/);
});

test('markdown contains issue links, truthful per-platform results and build numbers', () => {
  const body = renderUpdate({repository, sha, base: 'b'.repeat(40), date: '2026-09-18', version: '1.0.0',
    commits: [{sha, subject: 'STA-5 시간 이동 [fix]', message: 'STA-5 시간 이동\nSTA-5 STA-4'}],
    results: pipelines.map((p, i) => ({pipeline: p, run: run({path: p.path}),
      jobs: jobs(p, i === 2 ? 'skipped' : 'success'), artifacts: i === 1 ? [{name: 'cloudboard-alpha-aab-27'}] : []}))});
  assert.match(body, /관련 이슈: \[STA-5\].*\[STA-4\]/);
  assert.match(body, /빌드 27/);
  assert.match(body, /iOS\*\*: 건너뜀/);
  assert.match(body, /설치 가능 상태를 의미하지 않습니다/);
  assert.match(body, /테스트 필요/);
  assert.ok(body.includes('\\[fix\\]'));
});

function fakeLinear({ uncertainCreate = false } = {}) {
  const posts = new Map();
  const calls = [];
  return {posts, calls, api: async (query, variables) => {
    calls.push({query, variables});
    if (query.includes('query DeploymentUpdate')) return {projectUpdates: {nodes: posts.has(variables.id) ? [posts.get(variables.id)] : []}};
    if (query.includes('mutation PublishDeployment')) {
      const {id, projectId, body} = variables.input;
      assert.equal(posts.has(id), false, 'must not create a duplicate');
      const post = {id, body, project: {id: projectId}, url: `https://linear.app/post/${id}`};
      posts.set(id, post);
      if (uncertainCreate) throw new Error('response lost');
      return {projectUpdateCreate: {success: true, projectUpdate: post}};
    }
    const post = {...posts.get(variables.id), ...variables.input};
    posts.set(variables.id, post);
    return {projectUpdateUpdate: {success: true, projectUpdate: post}};
  }};
}

test('platform completions and reruns update one post without altering project health', async () => {
  const fake = fakeLinear();
  const args = {id: updateId(projectId, repository, sha), projectId, body: 'Web done, iOS pending'};
  assert.equal((await upsertUpdate(fake.api, args)).operation, 'created');
  assert.equal((await upsertUpdate(fake.api, args)).operation, 'unchanged');
  assert.equal((await upsertUpdate(fake.api, {...args, body: 'All uploads complete'})).operation, 'updated');
  assert.equal(fake.posts.size, 1);
  for (const call of fake.calls) assert.equal(call.variables.input?.health, undefined);
});

test('lost create response is recovered by deterministic ID, never recreated', async () => {
  const fake = fakeLinear({uncertainCreate: true});
  const args = {id: updateId(projectId, repository, sha), projectId, body: 'Done'};
  await upsertUpdate(fake.api, args);
  assert.equal(fake.posts.size, 1);
  assert.equal(fake.calls.filter(c => c.query.includes('mutation PublishDeployment')).length, 1);
});

test('archived or moved update is not overwritten or recreated', async () => {
  for (const extra of [{archivedAt: 'today'}, {project: {id: 'other'}}]) {
    const fake = fakeLinear();
    fake.posts.set('id', {id: 'id', body: 'old', project: {id: projectId}, ...extra});
    await assert.rejects(upsertUpdate(fake.api, {id: 'id', projectId, body: 'new'}), /refusing/);
    assert.equal(fake.calls.length, 1);
  }
});

test('HTTP 200 GraphQL errors and API failures are not treated as success or logged verbatim', async () => {
  await assert.rejects(requestJson('https://api.linear.app/graphql', {}, async () => ({ok: true, json: async () => ({errors: [{message: 'sensitive detail'}]})})), /GraphQL request failed/);
  await assert.rejects(requestJson('https://api.github.com/', {}, async () => ({ok: false, status: 403})), /HTTP 403/);
});

test('commit range covers multi-commit main pushes and merge branch contents', () => {
  const previousCwd = process.cwd();
  const directory = mkdtempSync(join(tmpdir(), 'cloudboard-linear-test-'));
  const git = (...args) => execFileSync('git', args, {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
  const commit = (file, message) => {writeFileSync(file, message); git('add', file); git('commit', '-m', message); return git('rev-parse', 'HEAD');};
  try {
    process.chdir(directory);
    git('init', '-b', 'main'); git('config', 'user.email', 'test@example.invalid'); git('config', 'user.name', 'Test');
    const base = commit('base', 'base');
    commit('one', 'one'); commit('two', 'STA-5 two');
    const direct = git('rev-parse', 'HEAD');
    assert.deepEqual(changeRange(direct, new Set([base])).commits.map(c => c.subject), ['one', 'STA-5 two']);
    git('checkout', '-b', 'develop'); commit('three', 'three'); commit('four', 'four');
    git('checkout', 'main'); git('merge', '--no-ff', 'develop', '-m', 'STA-4 merge develop');
    const range = changeRange(git('rev-parse', 'HEAD'), new Set([base, direct]));
    assert.equal(range.base, direct);
    assert.deepEqual(range.commits.map(c => c.subject), ['three', 'four']);
    assert.match(range.commits[0].message, /STA-4/);
  } finally {process.chdir(previousCwd); rmSync(directory, {recursive: true, force: true});}
});
