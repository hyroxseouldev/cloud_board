import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join} from 'node:path';
import test from 'node:test';
import {canonical, hash} from './common.mjs';
import {targets} from './release.mjs';
import {prepareSmokeInputs} from './smoke-inputs.mjs';

const sha = 'a'.repeat(40), previousSha = 'b'.repeat(40), tag = 'v1.3.2';
const repository = 'owner/cloud_board';
const id = {sha, runId: '900', attempt: '1'};

// Exercise Node's actual entrypoint/module initialization, not an imported
// requireNoRollback function. No request can escape this mocked fetch.
function mockGithub(scenario) {
  const requests = [];
  globalThis.fetch = async (url, options) => {
    if (options.method !== 'GET') throw new Error('Unexpected mutating request');
    const parsed = new URL(url);
    if (parsed.origin !== 'https://api.github.com') throw new Error('Unexpected API origin');
    const path = parsed.pathname + parsed.search;
    requests.push(path);
    const prefix = `/repos/${process.env.GITHUB_REPOSITORY}`;
    const sha = 'a'.repeat(40), previousSha = 'b'.repeat(40), tag = process.env.RELEASE_TAG;
    let value;
    if (path === `${prefix}/git/ref/tags/${tag}`) {
      value = {object: {type: 'commit', sha: scenario === 'moved-tag' ? previousSha : sha}};
    } else if (path === `${prefix}/compare/${sha}...main`) {
      value = {status: 'ahead', merge_base_commit: {sha}};
    } else if (path === `${prefix}/actions/workflows/firebase-hosting-merge.yml/runs?branch=${tag}&per_page=100`) {
      value = {total_count: 0, workflow_runs: []};
    } else if (path === `${prefix}/actions/workflows/firebase-hosting-merge.yml/runs?per_page=100`) {
      value = {workflow_runs: [{id: 800, run_attempt: 1, head_sha: previousSha, head_branch: 'v1.2.1',
        head_repository: {full_name: process.env.GITHUB_REPOSITORY}, event: 'workflow_dispatch', status: 'completed', conclusion: 'success'}]};
    } else if (path === `${prefix}/actions/runs/800/attempts/1/jobs?per_page=100`) {
      value = {jobs: [{name: 'firebase-production', conclusion: 'success', steps: [
        {name: 'Deploy account deletion functions and data rules', conclusion: 'success'},
        {name: 'Deploy to Firebase Hosting', conclusion: 'success'},
      ]}]};
    } else if (path === `${prefix}/compare/${previousSha}...${sha}`) {
      value = scenario === 'rollback' ? {status: 'behind', merge_base_commit: {sha}}
        : {status: 'ahead', merge_base_commit: {sha: previousSha}};
    } else throw new Error(`Unexpected API request: ${path}`);
    return {ok: true, json: async () => value};
  };
  process.on('exit', () => process.stdout.write(`${JSON.stringify({requests})}\n`));
}

function invoke(command, scenario = 'valid') {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), 'cloudboard-release-cli-')));
  try {
    cpSync(new URL('./', import.meta.url), join(directory, 'tool/firebase'), {recursive: true});
    const put = (file, value) => {
      mkdirSync(dirname(join(directory, file)), {recursive: true});
      writeFileSync(join(directory, file), typeof value === 'string' ? value : `${JSON.stringify(value, null, 2)}\n`);
    };
    const validation = {schemaVersion: 1, kind: 'release-validation', sourceSha: sha, releaseTag: tag,
      runId: id.runId, runAttempt: id.attempt, validationMode: 'skipped', reason: 'CLI regression fixture', actor: 'test'};
    const ruleFiles = ['firestore.rules', 'database.rules.json', 'storage.rules'];
    for (const file of ruleFiles) put(file, '{}');
    for (const file of ['functions/src/index.js', 'functions/tools/check.mjs', 'functions/certificates/test.pem', 'build/web/index.html']) put(file, 'fixture');
    put('build/release/validation/release.json', validation);
    put('build/contracts/workout-save-current.json', {format: 1, scenarios: [{contentOnly: true,
      writes: [{workout: {author: {}}, summary: {}}]}]});
    put('build/contracts/app-current.json', {format: 1, playback: [{split: true, state: {}, snapshot: {author: {}}}]});
    prepareSmokeInputs({sourceSha: sha, rootDir: directory});
    const paths = [...ruleFiles, 'tool/firebase/support-retirements.json', 'tool/firebase/support_retirements.mjs',
      'functions/src/index.js', 'functions/tools/check.mjs', 'functions/certificates/test.pem', 'build/web/index.html',
      'build/release/validation/release.json', ...['app-current.json', 'workout-save-current.json', 'metadata.json']
        .map(name => `build/release/smoke-inputs/${name}`)];
    const manifest = {format: 1, ...id, scope: 'full', validation, releaseTag: tag, targets,
      databaseSemanticHash: hash(canonical({})),
      files: Object.fromEntries(paths.map(file => [file, hash(readFileSync(join(directory, file)))]))};
    put('build/release/manifest.json', manifest);
    put('build/release/live-rules.json', {status: 'success', services: Object.fromEntries(
      ['firestore', 'database', 'storage'].map((service, index) => [service, {version: 'fixture',
        sourceHash: manifest.files[ruleFiles[index]], ...(service === 'database' ? {semanticHash: manifest.databaseSemanticHash} : {})}]))});
    put('build/release/smoke.json', {status: 'success', cleanup: 'success', runId: '900-1', checks: ['workout', 'storage', 'tv', 'isolation']});
    const preload = `data:text/javascript,${encodeURIComponent(`(${mockGithub})(${JSON.stringify(scenario)});`)}`;
    const result = spawnSync(process.execPath, ['--import', preload, join(directory, 'tool/firebase/release.mjs'), command], {
      cwd: directory, encoding: 'utf8', timeout: 5000,
      env: {...process.env, GITHUB_TOKEN: 'test-only', GITHUB_REPOSITORY: repository, RELEASE_SOURCE_SHA: sha,
        GITHUB_SHA: sha, GITHUB_REF: `refs/tags/${tag}`, RELEASE_TAG: tag, GITHUB_RUN_ID: id.runId,
        GITHUB_RUN_ATTEMPT: id.attempt, GITHUB_EVENT_NAME: 'workflow_dispatch', FIREBASE_DEPLOY_SCOPE: 'full', RELEASE_VALIDATION_MODE: 'skipped'},
    });
    const receipt = join(directory, 'build/release/release.json');
    return {...result, requests: JSON.parse(result.stdout.trim()).requests,
      receipt: existsSync(receipt) ? JSON.parse(readFileSync(receipt)) : null};
  } finally {
    rmSync(directory, {recursive: true, force: true});
  }
}

for (const command of ['current', 'ready']) {
  test(`release CLI ${command} completes module loading and checks both deployed components`, () => {
    const result = invoke(command);
    assert.equal(result.status, 0, result.stderr || String(result.error));
    assert.equal(result.requests.filter(path => path.endsWith(`/compare/${previousSha}...${sha}`)).length, 2);
    if (command === 'ready') {
      assert.equal(result.receipt.status, 'success');
      assert.equal(result.receipt.sha, sha);
      assert.equal(result.receipt.manifest.validation.validationMode, 'skipped');
    } else assert.equal(result.receipt, null);
  });
  for (const [scenario, message] of [['moved-tag', /Release tag moved/], ['rollback', /newer backend production attempt exists/]]) {
    test(`release CLI ${command} rejects ${scenario} before writing a receipt`, () => {
      const result = invoke(command, scenario);
      assert.equal(result.status, 1, result.stderr || String(result.error));
      assert.match(result.stderr, message);
      assert.equal(result.receipt, null);
    });
  }
}
