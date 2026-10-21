import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {appendFileSync, readFileSync, writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {booleanInput, deploymentTargets} from './deployment_targets.mjs';

const shaPattern = /^[a-f0-9]{40}$/;
const workflow = 'firebase-hosting-merge.yml';
const git = (...args) => execFileSync('git', args, {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();

export function releaseStartPlan({tag, server = false, web = false, mobile = false, skipCi = false, reason = '', sourceSha,
  ref, eventName, repository, actor, runId, runAttempt, runGit = git}) {
  assert.equal(eventName, 'workflow_dispatch', 'Start releases with a manual workflow dispatch');
  assert.equal(ref, 'refs/heads/main', 'Run Start production release from main');
  assert.match(repository || '', /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/, 'Invalid repository');
  assert.match(sourceSha || '', shaPattern, 'Missing fixed source SHA');
  assert(typeof tag === 'string' && tag.length <= 60 && /^v\d+\.\d+\.\d+$/.test(tag), 'Use a vX.Y.Z release tag');
  const targets = deploymentTargets({server, web, mobile});
  const {scope} = targets;
  assert.equal(typeof skipCi, 'boolean', 'skip_ci must be a boolean');
  assert(!(skipCi && scope === 'verify'), 'Mobile-only validation requires CI; use the separate manual mobile release for an audited CI skip');
  assert(typeof reason === 'string' && reason.length <= 2000, 'CI skip reason must be at most 2000 characters');
  assert(!skipCi || reason.trim(), 'skip_ci_reason is required when skipping CI');
  assert(typeof actor === 'string' && actor.trim() && !/[\r\n]/.test(actor), 'Missing release actor');
  assert.match(runId || '', /^\d+$/, 'Missing workflow run ID');
  assert.match(runAttempt || '', /^[1-9]\d*$/, 'Missing workflow run attempt');
  assert.equal(runGit('rev-parse', 'HEAD'), sourceSha, 'Checkout must match the fixed workflow SHA');
  const version = runGit('show', `${sourceSha}:pubspec.yaml`).match(/^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$/m)?.[1];
  assert.equal(tag, `v${version}`, 'Release tag must match the selected pubspec version');
  return {schemaVersion: 1, kind: 'release-start', repository, sourceSha, releaseTag: tag, scope,
    targets, skipCi, reason: skipCi ? reason.trim() : '', actor, runId, runAttempt};
}

export async function startRelease(plan, {request, record = () => {}}) {
  const base = `/repos/${plan.repository}`;
  const main = await request(`${base}/git/ref/heads/main`);
  assert.equal(main.status, 200, 'Cannot confirm current main');
  const mainSha = main.data?.object?.sha;
  assert.match(mainSha || '', shaPattern, 'Invalid current main SHA');
  const comparison = await request(`${base}/compare/${plan.sourceSha}...${mainSha}`);
  assert(comparison.status === 200 && ['ahead', 'identical'].includes(comparison.data?.status),
    'Selected source is not in current main history');

  const existing = await request(`${base}/git/ref/tags/${plan.releaseTag}`);
  assert.equal(existing.status, 404, existing.status === 200
    ? 'Release tag already exists; never overwrite or reuse it. Use the existing release workflow for a retry.'
    : 'Cannot confirm that the release tag is unused');
  const history = await request(`${base}/actions/workflows/${workflow}/runs?branch=${encodeURIComponent(plan.releaseTag)}&per_page=1`);
  assert(history.status === 200 && Number.isInteger(history.data?.total_count) && Array.isArray(history.data?.workflow_runs),
    'Cannot confirm release workflow history');
  assert(history.data.total_count === 0 && history.data.workflow_runs.length === 0,
    'This release tag has workflow history; never recreate or reuse it');

  const created = await request(`${base}/git/refs`, {method: 'POST', body: {ref: `refs/tags/${plan.releaseTag}`, sha: plan.sourceSha}});
  assert.equal(created.status, 201, 'Tag creation failed; no release dispatch was requested');
  const receipt = {...plan, tagCreated: true, dispatchStatus: 'not_requested'};
  record(receipt);
  try {
    receipt.dispatchStatus = 'requested';
    record(receipt);
    // Do not retry this request automatically: a timeout can occur after GitHub accepted it.
    const dispatched = await request(`${base}/actions/workflows/${workflow}/dispatches`, {method: 'POST', body: {
      ref: plan.releaseTag,
      inputs: {confirm_sha: plan.sourceSha, scope: plan.scope, deploy_mobile: String(plan.targets.mobile),
        skip_ci: String(plan.skipCi), skip_ci_reason: plan.reason},
    }});
    assert.equal(dispatched.status, 204, `Workflow dispatch was not confirmed (HTTP ${dispatched.status})`);
    receipt.dispatchStatus = 'accepted';
    record(receipt);
    return receipt;
  } catch (error) {
    receipt.dispatchStatus = 'failed_or_unconfirmed';
    record(receipt);
    throw new Error(`Tag ${plan.releaseTag} remains at ${plan.sourceSha}. Dispatch failed or was not confirmed. ` +
      `Check Actions for an existing run before retrying ${workflow} manually from this tag with ` +
      `confirm_sha=${plan.sourceSha}, scope=${plan.scope}, deploy_mobile=${plan.targets.mobile} and the same CI choice. Do not delete or move the tag.`, {cause: error});
  }
}

async function githubRequest(path, {method = 'GET', body} = {}) {
  const response = await fetch(`https://api.github.com${path}`, {method,
    headers: {Authorization: `Bearer ${process.env.GITHUB_TOKEN}`, Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28', ...(body ? {'Content-Type': 'application/json'} : {})},
    ...(body ? {body: JSON.stringify(body)} : {}), signal: AbortSignal.timeout(30_000)});
  return {status: response.status, data: response.status === 204 ? null : await response.json()};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const env = process.env;
    assert(env.GITHUB_TOKEN, 'The workflow GITHUB_TOKEN is required');
    const inputs = JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8')).inputs ?? {};
    assert(inputs.scope === undefined, 'Use deploy_server, deploy_web and deploy_mobile instead of scope');
    const plan = releaseStartPlan({tag: inputs.tag,
      server: booleanInput(inputs.deploy_server, 'deploy_server'),
      web: booleanInput(inputs.deploy_web, 'deploy_web'),
      mobile: booleanInput(inputs.deploy_mobile, 'deploy_mobile'),
      skipCi: booleanInput(inputs.skip_ci, 'skip_ci'),
      reason: inputs.skip_ci_reason || '', sourceSha: env.GITHUB_SHA, ref: env.GITHUB_REF,
      eventName: env.GITHUB_EVENT_NAME, repository: env.GITHUB_REPOSITORY, actor: env.GITHUB_ACTOR,
      runId: env.GITHUB_RUN_ID, runAttempt: env.GITHUB_RUN_ATTEMPT});
    const receipt = await startRelease(plan, {request: githubRequest,
      record: value => writeFileSync('release-start.json', `${JSON.stringify(value, null, 2)}\n`)});
    const summary = `## Production release requested\n\nTag: \`${receipt.releaseTag}\`\n\nSource: \`${receipt.sourceSha}\`\n\n` +
      `Targets: server=${receipt.targets.server}, web=${receipt.targets.web}, mobile=${receipt.targets.mobile}.\n\n` +
      `Firebase scope: ${receipt.scope}; CI: ${receipt.skipCi ? 'SKIPPED (not passed)' : 'required (not yet verified)'}.\n\n` +
      `Requested by: ${receipt.actor}. ${receipt.reason ? `Reason (JSON): ${JSON.stringify(receipt.reason)}` : ''}\n\n` +
      'One Firebase release dispatch was accepted. Deployment and native upload results must be checked in their own runs.\n';
    if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, summary);
    console.log(`Release dispatch accepted: ${receipt.releaseTag} at ${receipt.sourceSha}`);
  } catch (error) {
    if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `## Release start did not complete\n\n${error.message}\n`);
    console.error(error.message);
    process.exitCode = 1;
  }
}
