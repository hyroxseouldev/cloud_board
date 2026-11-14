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
  console.error('Actions release dispatch is retired. Use node tool/release/direct.mjs with a fixed source commit and explicit scope.');
  process.exitCode = 1;
}
