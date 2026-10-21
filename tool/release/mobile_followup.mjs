import assert from 'node:assert/strict';
import {appendFileSync, readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {github, isReleaseTag} from '../firebase/release.mjs';
import {readReleaseArtifact} from '../firebase/github-artifact.mjs';
import {validateReleaseValidation} from '../firebase/release-validation.mjs';

export async function mobileFollowupDecision({eventName, event = {}, repository, request, readArtifact}) {
  // Explicit manual mobile runs and development-tag QA retain their own gates.
  if (eventName === 'workflow_dispatch' || eventName === 'push') {
    return {requested: true, reason: 'Explicit mobile run; existing source, CI and environment checks still apply.'};
  }
  assert.equal(eventName, 'workflow_run', 'Unsupported mobile trigger');
  assert.match(repository || '', /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/, 'Invalid repository');
  const run = event.workflow_run;
  assert(run?.status === 'completed' && run.conclusion === 'success' &&
    run.head_repository?.full_name === repository &&
    run.path === '.github/workflows/firebase-hosting-merge.yml' &&
    ['push', 'workflow_dispatch'].includes(run.event), 'Mobile follow-up requires this repository’s successful release workflow');
  assert(isReleaseTag(run.head_branch), 'Mobile follow-up requires a release tag');
  assert.match(run.head_sha || '', /^[a-f0-9]{40}$/, 'Missing release source SHA');
  for (const field of ['id', 'run_attempt']) {
    assert(Number.isSafeInteger(run[field]) && run[field] > 0, `Missing release ${field}`);
  }
  const response = await request(`/repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`);
  assert(Number.isInteger(response.total_count) && response.total_count >= 0 && response.total_count <= 100 &&
    Array.isArray(response.artifacts) && response.artifacts.length === response.total_count,
  'Cannot verify complete release artifact inventory');
  const expectedName = `release-validation-${run.id}-${run.run_attempt}`;
  const matches = response.artifacts.filter(artifact => artifact.name === expectedName);
  assert(matches.length === 1 && !matches[0].expired, 'Missing, expired or ambiguous mobile selection receipt');
  const receipt = validateReleaseValidation(await readArtifact(matches[0]), {
    sourceSha: run.head_sha, releaseTag: run.head_branch, runId: String(run.id), runAttempt: String(run.run_attempt),
  });
  const requested = receipt.mobileUploadRequested === true;
  return {requested, reason: requested
    ? 'Mobile selected in the completed release; source, CI and backend compatibility checks still apply.'
    : 'Mobile not selected in this release receipt. No mobile build or upload will run; use an explicit manual mobile run if needed.'};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const env = process.env;
    const decision = await mobileFollowupDecision({
      eventName: env.GITHUB_EVENT_NAME, event: JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8')),
      repository: env.GITHUB_REPOSITORY, request: github,
      readArtifact: artifact => readReleaseArtifact(artifact, env.GITHUB_REPOSITORY, env.GITHUB_TOKEN),
    });
    assert(env.GITHUB_OUTPUT, 'Workflow output path is required');
    appendFileSync(env.GITHUB_OUTPUT, `requested=${decision.requested}\n`);
    if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, `## Mobile release selection\n\n${decision.reason}\n`);
    console.log(decision.reason);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
