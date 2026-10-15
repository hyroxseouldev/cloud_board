import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdtempSync, rmSync, mkdirSync, existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {pipelines, trustedRun, latestRuns, deploymentStatus, sourceRunId, requestJson, readCorrection, publish} from './publish.mjs';

const repository = 'test/repo';
const sha = 'a'.repeat(40);
const note = JSON.parse(readFileSync(new URL('../../release-notes/current.json', import.meta.url), 'utf8'));
const run = (extra = {}) => ({id: 123, run_number: 82, run_attempt: 2, head_sha: sha,
  head_branch: 'main', head_repository: {full_name: repository}, event: 'push',
  path: pipelines[0].path, status: 'completed', conclusion: 'success', ...extra});
const jobs = (pipeline, conclusion = 'success') => [{conclusion, steps: [{name: pipeline.step, conclusion}]}];

test('only own main deployments qualify and latest runs cannot be contaminated by other sources', () => {
  assert.equal(trustedRun(run(), repository), true);
  assert.equal(trustedRun(run({event: 'workflow_dispatch'}), repository), true);
  for (const extra of [{head_branch: 'develop'}, {event: 'pull_request'},
    {head_repository: {full_name: 'someone/fork'}}, {path: '.github/workflows/untrusted.yml'}]) {
    assert.equal(trustedRun(run(extra), repository), false);
    assert.throws(() => sourceRunId({workflow_run: run(extra)}, 'workflow_run', '', repository), /main deployment/);
  }
  const selected = latestRuns([run(), run({run_attempt: 3, conclusion: 'failure'}),
    run({id: 125, event: 'pull_request'}), run({id: 126, head_sha: 'b'.repeat(40)}),
    run({id: 127, head_repository: {full_name: 'someone/fork'}})], sha, repository);
  assert.equal(selected[0].run_attempt, 3);
  assert.equal(selected[0].conclusion, 'failure');
  assert.deepEqual(selected.slice(1), [null, null]);
  assert.equal(latestRuns([run(), run({id: 124, status: 'queued', conclusion: null})], sha, repository)[0].id, 124);
});

test('deployment summaries require successful steps and preserve actual Android track', () => {
  for (const pipeline of pipelines) {
    assert.equal(deploymentStatus(pipeline, run(), jobs(pipeline)), pipeline.success);
    assert.match(deploymentStatus(pipeline, run(), jobs(pipeline, 'skipped')), /건너뜀/);
    assert.match(deploymentStatus(pipeline, run(), [{conclusion: 'success', steps: []}]), /확인 필요/);
    for (const conclusion of ['failure', 'timed_out']) {
      assert.match(deploymentStatus(pipeline, run({conclusion}), jobs(pipeline, 'failure')), /실패/);
    }
    assert.match(deploymentStatus(pipeline, run({conclusion: 'cancelled'}), []), /취소/);
    assert.match(deploymentStatus(pipeline, run({status: 'in_progress', conclusion: null}), []), /진행 중/);
    assert.match(deploymentStatus(pipeline, run({status: 'queued', conclusion: null}), []), /대기 중/);
    assert.match(deploymentStatus(pipeline, null), /기록 없음/);
    assert.match(deploymentStatus(pipeline, run({conclusion: 'failure'}), jobs(pipeline)), /후속 작업/);
  }
  const android = pipelines.find(pipeline => pipeline.key === 'android');
  assert.equal(deploymentStatus(android, run(), jobs(android)), '내부 테스트 트랙 업로드 완료');
  assert.equal(deploymentStatus(android, run(), [{steps: [{
    name: 'Upload mobile and TV bundle to closed Alpha testing', conclusion: 'success',
  }]}]), '비공개 Alpha 트랙 제출 완료');
});

test('manual recovery accepts only numeric deployment IDs on main', () => {
  assert.equal(sourceRunId({inputs: {deployment_run_id: '123'}}, 'workflow_dispatch', 'refs/heads/main', repository), '123');
  assert.throws(() => sourceRunId({inputs: {deployment_run_id: '123'}}, 'workflow_dispatch', 'refs/heads/develop', repository));
  for (const id of ['../secrets', '', '123?branch=other']) {
    assert.throws(() => sourceRunId({inputs: {deployment_run_id: id}}, 'workflow_dispatch', 'refs/heads/main', repository));
  }
});

test('HTTP failures report status without exposing API response bodies or credentials', async () => {
  const secret = 'sensitive-response-token';
  await assert.rejects(requestJson('https://api.github.com/repos/test/repo', {
    headers: {Authorization: `Bearer ${secret}`},
  }, async (_url, options) => {
    assert.ok(options.signal instanceof AbortSignal);
    return {ok: false, status: 403, json: async () => ({message: secret})};
  }), error => /api.github.com, HTTP 403/.test(error.message) && !error.message.includes(secret));
  assert.deepEqual(await requestJson('https://api.github.com/', {}, async () => ({
    ok: true, json: async () => ({workflow_runs: []}),
  })), {workflow_runs: []});
});

async function withDeployment(options, check) {
  const previousCwd = process.cwd();
  const directory = mkdtempSync(join(tmpdir(), 'cloudboard-app-news-'));
  const git = (...args) => execFileSync('git', args, {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
  try {
    process.chdir(directory);
    git('init', '-b', 'main');
    git('config', 'user.email', 'test@example.invalid');
    git('config', 'user.name', 'Test');
    writeFileSync('pubspec.yaml', `version: ${options.version ?? note.version}+2\n`);
    if (options.withNews !== false) {
      mkdirSync('release-notes');
      writeFileSync('release-notes/current.json', JSON.stringify(options.news ?? note));
    }
    git('add', '.');
    git('commit', '-m', 'deployed release');
    const deployedSha = git('rev-parse', 'HEAD');
    const deployments = pipelines.map((pipeline, index) => ({pipeline,
      run: run({id: 123 + index, head_sha: deployedSha, path: pipeline.path}),
      jobs: jobs(pipeline),
      artifacts: pipeline.key === 'web' ? [] : [{name: pipeline.key === 'android'
        ? 'cloudboard-internal-aab-52' : 'cloudboard-ios-dsyms-542'}],
    }));
    const eventPath = join(directory, 'event.json');
    writeFileSync(eventPath, JSON.stringify({workflow_run: deployments[0].run}));
    const env = {GITHUB_EVENT_PATH: eventPath, GITHUB_REPOSITORY: repository,
      GITHUB_TOKEN: 'github-test-only', GITHUB_EVENT_NAME: 'workflow_run', GITHUB_REF: 'refs/heads/main',
      UPDATE_NEWS_OUTPUT_PATH: join(directory, 'output.json'), GITHUB_STEP_SUMMARY: join(directory, 'summary.md')};
    const requests = [];
    const fakeFetch = async (url, requestOptions) => {
      const parsed = new URL(url);
      assert.equal(parsed.origin, 'https://api.github.com', 'publishing app news must call only GitHub');
      assert.equal(requestOptions.headers.Authorization, 'Bearer github-test-only');
      assert.ok(!requestOptions.method || requestOptions.method === 'GET', 'only deployment reads are needed');
      requests.push(parsed.pathname);
      const prefix = `/repos/${repository}/actions/runs`;
      let data;
      if (parsed.pathname === prefix) {
        assert.equal(parsed.searchParams.get('head_sha'), deployedSha);
        assert.equal(parsed.searchParams.get('branch'), null);
        data = {workflow_runs: deployments.map(result => result.run)};
      } else {
        const deployment = deployments.find(result => parsed.pathname.startsWith(`${prefix}/${result.run.id}`));
        assert.ok(deployment, `unexpected GitHub path: ${parsed.pathname}`);
        const runPath = `${prefix}/${deployment.run.id}`;
        if (parsed.pathname === runPath) data = deployment.run;
        else if (parsed.pathname === `${runPath}/attempts/${deployment.run.run_attempt}/jobs`) data = {jobs: deployment.jobs};
        else if (parsed.pathname === `${runPath}/artifacts`) data = {artifacts: deployment.artifacts};
        else assert.fail(`unexpected GitHub path: ${parsed.pathname}`);
      }
      return {ok: true, json: async () => data};
    };
    await check({directory, git, env, deployments, fakeFetch, requests, deployedSha});
  } finally {
    process.chdir(previousCwd);
    rmSync(directory, {recursive: true, force: true});
  }
}

test('publisher needs no Linear credentials and prepares deployed-SHA editorial with confirmed builds', async () => {
  await withDeployment({}, async ({git, env, fakeFetch, deployedSha}) => {
    writeFileSync('release-notes/current.json', JSON.stringify({...note, title: 'Not deployed yet'}));
    git('add', 'release-notes/current.json');
    git('commit', '-m', 'newer editorial checkout');
    assert.notEqual(git('rev-parse', 'HEAD'), deployedSha);
    const result = await publish(env, fakeFetch);
    const payload = JSON.parse(readFileSync(env.UPDATE_NEWS_OUTPUT_PATH, 'utf8'));
    assert.equal(result.operation, 'prepared');
    assert.deepEqual(payload, {...note, builds: {web: '82.2', android: '52', ios: '542'}});
    assert.deepEqual(result.news, payload);
    assert.ok(readFileSync(env.GITHUB_STEP_SUMMARY, 'utf8').includes(deployedSha));
  });
});

test('QA TestFlight uploads and build-only runs never publish public app news', async () => {
  await withDeployment({}, async ({env, deployments, fakeFetch}) => {
    const ios = deployments[2];
    ios.jobs[0].steps.push({name: 'QA build does not publish app update news', conclusion: 'success'});
    writeFileSync(env.GITHUB_EVENT_PATH, JSON.stringify({workflow_run: ios.run}));
    assert.deepEqual(await publish(env, fakeFetch), {operation: 'skipped', reason: 'qa-build'});
    assert.equal(existsSync(env.UPDATE_NEWS_OUTPUT_PATH), false);
    ios.jobs = [{steps: [{name: 'Resolve and pin trusted app source', conclusion: 'success'}]}];
    assert.deepEqual(await publish(env, fakeFetch), {operation: 'skipped', reason: 'no-deployed-builds'});
    assert.equal(existsSync(env.UPDATE_NEWS_OUTPUT_PATH), false);
  });
});

test('development receipt excludes an uploaded build even without the QA marker step', async () => {
  await withDeployment({}, async ({env, deployments, fakeFetch, deployedSha}) => {
    const ios = deployments[2];
    ios.run.event = 'workflow_run';
    ios.jobs[0].steps.push({name: 'Resolve and pin trusted app source', conclusion: 'success'});
    ios.artifacts.push({name: `mobile-source-${ios.run.id}-${ios.run.run_attempt}`});
    writeFileSync(env.GITHUB_EVENT_PATH, JSON.stringify({workflow_run: ios.run}));
    assert.deepEqual(await publish(env, fakeFetch, async () => ({schemaVersion: 2, kind: 'mobile-source',
      sourceSha: deployedSha, workflowSha: deployedSha, releaseMode: 'qa', environment: 'development', platform: 'ios',
      firebaseProject: 'cloud-board-development', package: 'com.sunmkim.cloudboard.dev', environmentBindingVerified: true,
      version: note.version, build: '542', artifactSha256: 'c'.repeat(64), runId: String(ios.run.id), runAttempt: String(ios.run.run_attempt)})),
    {operation: 'skipped', reason: 'qa-build'});
    assert.equal(existsSync(env.UPDATE_NEWS_OUTPUT_PATH), false);
  });
});
test('production-connected QA receipt excludes an uploaded build even without the QA marker step', async () => {
  await withDeployment({}, async ({env, deployments, fakeFetch, deployedSha}) => {
    const ios = deployments[2];
    ios.run.event = 'workflow_run';
    ios.jobs[0].steps.push({name: 'Resolve and pin trusted app source', conclusion: 'success'});
    ios.artifacts.push({name: `mobile-source-${ios.run.id}-${ios.run.run_attempt}`});
    writeFileSync(env.GITHUB_EVENT_PATH, JSON.stringify({workflow_run: ios.run}));
    assert.deepEqual(await publish(env, fakeFetch, async () => ({schemaVersion: 2, kind: 'mobile-source',
      sourceSha: deployedSha, workflowSha: deployedSha, releaseMode: 'qa', environment: 'production', platform: 'ios',
      firebaseProject: 'cloud-board-stationd', package: 'com.sunmkim.cloudboard', environmentBindingVerified: true,
      version: note.version, build: '542', artifactSha256: 'c'.repeat(64), runId: String(ios.run.id), runAttempt: String(ios.run.run_attempt)})),
    {operation: 'skipped', reason: 'qa-build'});
    assert.equal(existsSync(env.UPDATE_NEWS_OUTPUT_PATH), false);
  });
});

test('versioned production tag deployment and main native workflow-run are trusted; arbitrary tags are not', () => {
  assert.equal(trustedRun(run({head_branch: 'v1.2.2'}), repository), true);
  assert.equal(trustedRun(run({event: 'workflow_run', path: pipelines[2].path}), repository), true);
  for (const head_branch of ['v-next', 'v1.2.2-rc1', 'test']) assert.equal(trustedRun(run({head_branch}), repository), false);
  assert.equal(trustedRun(run({event: 'workflow_run'}), repository), false);
});

test('release TestFlight news uses artifact app source instead of the newer workflow commit', async () => {
  await withDeployment({}, async ({git, env, deployments, fakeFetch, deployedSha}) => {
    writeFileSync('workflow-only.txt', 'new control workflow');
    git('add', 'workflow-only.txt'); git('commit', '-m', 'workflow update');
    const workflowSha = git('rev-parse', 'HEAD');
    const ios = deployments[2];
    ios.run.head_sha = workflowSha;
    ios.jobs[0].steps.push({name: 'Resolve and pin trusted app source', conclusion: 'success'});
    ios.artifacts.push({name: `mobile-source-${ios.run.id}-${ios.run.run_attempt}`});
    writeFileSync(env.GITHUB_EVENT_PATH, JSON.stringify({workflow_run: ios.run}));
    const result = await publish(env, fakeFetch, async () => ({schemaVersion: 1, kind: 'mobile-source',
      sourceSha: deployedSha, workflowSha, releaseMode: 'release', platform: 'ios',
      firebaseProject: 'cloud-board-stationd', package: 'com.sunmkim.cloudboard', productionBindingVerified: true,
      version: note.version, build: '542', artifactSha256: 'c'.repeat(64), runId: String(ios.run.id), runAttempt: String(ios.run.run_attempt)}));
    assert.equal(result.operation, 'prepared');
    assert.equal(result.news.builds.ios, '542');
    assert(readFileSync(env.GITHUB_STEP_SUMMARY, 'utf8').includes(deployedSha));
  });
});

test('historical missing news and unconfirmed deployments skip publication and remove stale payloads', async () => {
  for (const reason of ['no-news', 'failed-upload', 'missing-artifact']) {
    await withDeployment({withNews: reason !== 'no-news'}, async ({env, deployments, fakeFetch}) => {
      writeFileSync(env.UPDATE_NEWS_OUTPUT_PATH, '{"stale":true}');
      if (reason === 'failed-upload') {
        for (const result of deployments) {
          result.run.conclusion = 'failure';
          result.jobs = jobs(result.pipeline, 'failure');
        }
      } else if (reason === 'missing-artifact') {
        deployments[0].jobs = jobs(pipelines[0], 'skipped');
        for (const result of deployments) result.artifacts = [];
      }
      assert.deepEqual(await publish(env, fakeFetch), {operation: 'skipped',
        reason: reason === 'no-news' ? 'no-news' : 'no-deployed-builds'});
      assert.equal(existsSync(env.UPDATE_NEWS_OUTPUT_PATH), false);
      assert.match(readFileSync(env.GITHUB_STEP_SUMMARY, 'utf8'), /Skipped:/);
    });
  }
});

test('mismatched editorial versions and untrusted fetched runs fail without leaving stale payloads', async () => {
  await withDeployment({version: '9.9.9'}, async ({env, fakeFetch}) => {
    writeFileSync(env.UPDATE_NEWS_OUTPUT_PATH, '{"stale":true}');
    await assert.rejects(publish(env, fakeFetch), /version must match/);
    assert.equal(existsSync(env.UPDATE_NEWS_OUTPUT_PATH), false);
  });
  await withDeployment({}, async ({env, deployments, fakeFetch}) => {
    // A valid event cannot authorize a run which the GitHub lookup reports as untrusted.
    deployments[0].run.head_repository = {full_name: 'someone/fork'};
    writeFileSync(env.UPDATE_NEWS_OUTPUT_PATH, '{"stale":true}');
    await assert.rejects(publish(env, fakeFetch), /no longer a trusted main run/);
    assert.equal(existsSync(env.UPDATE_NEWS_OUTPUT_PATH), false);
  });
});

test('dry runs verify deployments without requiring or writing an output payload', async () => {
  await withDeployment({}, async ({env, fakeFetch}) => {
    const outputPath = env.UPDATE_NEWS_OUTPUT_PATH;
    delete env.UPDATE_NEWS_OUTPUT_PATH;
    const result = await publish({...env, UPDATE_NEWS_DRY_RUN: 'true'}, fakeFetch);
    assert.equal(result.operation, 'dry-run');
    assert.deepEqual(result.news.builds, {web: '82.2', android: '52', ios: '542'});
    assert.equal(existsSync(outputPath), false);
    assert.match(readFileSync(env.GITHUB_STEP_SUMMARY, 'utf8'), /Dry run: no app feed payload written/);
  });
});

function commitCorrection(git, deployedSha, news = note) {
  const path = `release-notes/corrections/${deployedSha}.json`;
  mkdirSync('release-notes/corrections', {recursive: true});
  writeFileSync(path, JSON.stringify(news));
  git('add', path);
  git('commit', '-m', 'review exact deployed-SHA news correction');
  return path;
}

const staleNews = {...note, id: 'old-release', version: '1.1.1'};

test('exact-SHA corrections recover stale or missing editorial using confirmed deployment builds', async () => {
  for (const options of [{news: staleNews}, {withNews: false}]) {
    await withDeployment(options, async ({git, env, deployments, fakeFetch, deployedSha}) => {
      const path = commitCorrection(git, deployedSha);
      const result = await publish(env, fakeFetch);
      assert.deepEqual(result.news, {...note, builds: {web: '82.2', android: '52', ios: '542'}});
      assert.match(readFileSync(env.GITHUB_STEP_SUMMARY, 'utf8'), new RegExp(path));
      // Editorial recovery cannot turn a failed upload into a deployed build.
      for (const deployment of deployments) deployment.jobs = jobs(deployment.pipeline, 'failure');
      assert.deepEqual(await publish(env, fakeFetch), {operation: 'skipped', reason: 'no-deployed-builds'});
      assert.equal(existsSync(env.UPDATE_NEWS_OUTPUT_PATH), false);
    });
  }
});

test('valid deployed editorial is never overridden by a later correction', async () => {
  await withDeployment({}, async ({git, env, fakeFetch, deployedSha}) => {
    commitCorrection(git, deployedSha, {...note, title: 'Not part of this deployed release'});
    const result = await publish(env, fakeFetch);
    assert.equal(result.news.title, note.title);
    assert.doesNotMatch(readFileSync(env.GITHUB_STEP_SUMMARY, 'utf8'), /Editorial correction:/);
  });
});

test('corrections require an exact SHA, committed content, and the deployed app version', async () => {
  for (const invalidSha of ['', '../current', 'a'.repeat(39), 'A'.repeat(40)]) {
    assert.throws(() => readCorrection(invalidSha), /Invalid correction commit SHA/);
  }
  await withDeployment({news: staleNews}, async ({git, env, fakeFetch, deployedSha}) => {
    commitCorrection(git, 'b'.repeat(40));
    await assert.rejects(publish(env, fakeFetch), /version must match/);
    const target = `release-notes/corrections/${deployedSha}.json`;
    writeFileSync(target, JSON.stringify(note));
    await assert.rejects(publish(env, fakeFetch), /version must match/);
    assert.equal(existsSync(env.UPDATE_NEWS_OUTPUT_PATH), false);
  });
  for (const correction of [{...note, version: '9.9.9'}, {...note, debugLog: 'not-public'}]) {
    await withDeployment({news: staleNews}, async ({git, env, fakeFetch, deployedSha}) => {
      commitCorrection(git, deployedSha, correction);
      await assert.rejects(publish(env, fakeFetch), /version must match|Unknown news field/);
      assert.equal(existsSync(env.UPDATE_NEWS_OUTPUT_PATH), false);
    });
  }
});

test('a correction cannot be edited or deleted and re-added after its first commit', async () => {
  for (const change of ['edit', 'delete-and-readd']) {
    await withDeployment({news: staleNews}, async ({git, env, fakeFetch, deployedSha}) => {
      const path = commitCorrection(git, deployedSha);
      if (change === 'edit') {
        // Even a whitespace-only edit changes the immutable Git blob.
        writeFileSync(path, `${JSON.stringify(note)}\n`);
        git('add', path);
        git('commit', '-m', 'change correction after approval');
      } else {
        git('rm', path);
        git('commit', '-m', 'delete correction');
        commitCorrection(git, deployedSha);
      }
      writeFileSync(env.UPDATE_NEWS_OUTPUT_PATH, '{"stale":true}');
      await assert.rejects(publish(env, fakeFetch), /correction is immutable/);
      assert.equal(existsSync(env.UPDATE_NEWS_OUTPUT_PATH), false);
    });
  }
});
