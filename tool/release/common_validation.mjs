import assert from 'node:assert/strict';
import {appendFileSync, writeFileSync} from 'node:fs';
import {parseArgs} from 'node:util';
import {pathToFileURL} from 'node:url';
import {isReleaseTag} from '../firebase/release.mjs';
import {productionRuns} from '../firebase/release-runs.mjs';
import {readReleaseArtifact} from '../firebase/github-artifact.mjs';
import {ciSkipDecision} from './source.mjs';

export function validateSkippedRelease(receipt, {run, sha, releaseTag}) {
  assert.equal(run.event, 'workflow_dispatch', 'Automatic tag pushes cannot skip CI');
  assert.equal(receipt?.schemaVersion, 1, 'Invalid release validation receipt');
  assert.equal(receipt.kind, 'release-validation', 'Invalid release validation receipt');
  assert.equal(receipt.sourceSha, sha, 'Validation receipt belongs to another source');
  assert.equal(receipt.releaseTag, releaseTag ?? run.head_branch, 'Validation receipt belongs to another tag');
  assert.equal(receipt.releaseTag, run.head_branch, 'Validation receipt tag differs from workflow run');
  assert.equal(receipt.runId, String(run.id), 'Validation receipt belongs to another run');
  assert.equal(receipt.runAttempt, String(run.run_attempt), 'Validation receipt belongs to another attempt');
  assert.equal(receipt.validationMode, 'skipped', 'Validation was not explicitly skipped');
  return ciSkipDecision({skipCi: true, reason: receipt.reason, actor: receipt.actor,
    mode: 'release', eventName: run.event});
}

export async function requireCommonValidation({repository, sha, releaseTag, request, readArtifact}) {
  assert.match(repository || '', /^[\w.-]+\/[\w.-]+$/);
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  if (releaseTag !== undefined) assert(isReleaseTag(releaseTag), 'Invalid release tag');
  const response = await request(`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?head_sha=${sha}&per_page=100`);
  assert((response.total_count ?? 0) <= 100, 'Too many validation runs to identify the latest attempt safely');
  const runs = productionRuns(response.workflow_runs ?? [], repository, sha).filter(run => isReleaseTag(run.head_branch) && (!releaseTag || run.head_branch === releaseTag));
  const checks = [
    {name: 'app-validation', steps: ['Analyze', 'Test']},
    {name: 'class_start_regressions / Class start lifecycle and TV preparation',
      steps: ['Required native logic regressions', 'Required web regressions']},
  ];
  for (const run of runs) {
    assert(Number.isSafeInteger(run.run_attempt) && run.run_attempt > 0,
      'Latest release validation attempt is missing; an older successful attempt cannot authorize release.');
    // Manual uploads follow the same completion rule as the automatic
    // workflow_run trigger. Passing app checks cannot bypass failed contracts
    // or an unfinished production release attempt.
    assert(run.status === 'completed' && run.conclusion === 'success',
      'Latest release validation workflow has not completed successfully; an older successful attempt cannot authorize release.');
    const {jobs} = await request(`/repos/${repository}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
    const passed = check => {
      const job = jobs?.find(job => job.name === check.name);
      return job?.conclusion === 'success' && check.steps.every(name =>
        job.steps?.some(step => step.name === name && step.conclusion === 'success'));
    };
    if (!checks.every(passed)) {
      const {artifacts} = await request(`/repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`);
      const matches = (artifacts ?? []).filter(artifact =>
        artifact.name === `release-validation-${run.id}-${run.run_attempt}` && !artifact.expired);
      if (matches.length > 0) {
        assert(matches.length === 1 && readArtifact, 'Ambiguous or unreadable release validation receipt');
        const receipt = await readArtifact(matches[0]);
        if (receipt.validationMode === 'skipped') {
          const decision = validateSkippedRelease(receipt, {run, sha, releaseTag});
          assert(jobs?.some(job => job.name === 'Verify deployment target' && job.conclusion === 'success') &&
            checks.every(check => {
              const names = [check.name, ...(check.name.startsWith('class_start_regressions /') ? ['class_start_regressions'] : [])];
              const matches = jobs?.filter(job => names.includes(job.name)) ?? [];
              return matches.length === 1 && matches[0].conclusion === 'skipped';
            }),
          'Latest release validation skip does not match planned skipped jobs');
          return {...run, ...decision};
        }
      }
    }
    // No explicit skip receipt: concrete successful checks remain mandatory.
    for (const check of checks) {
      const job = jobs?.find(job => job.name === check.name);
      assert(job?.conclusion === 'success' && check.steps.every(name =>
        job.steps?.some(step => step.name === name && step.conclusion === 'success')),
      `Latest release validation has not passed ${check.name}; an older successful attempt cannot authorize release.`);
    }
    // The separate backend gate still checks the live deployment at upload time.
    return {...run, validationMode: 'required'};
  }
  assert.fail('No release integration validation for this app source. Run the release-tag validation, or use QA mode for internal testing.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const {values} = parseArgs({options: {'source-sha': {type: 'string'}, 'release-tag': {type: 'string'}}});
  const env = process.env;
  const {GITHUB_TOKEN: token, GITHUB_REPOSITORY: repository} = env;
  const sha = values['source-sha'], releaseTag = values['release-tag'] ?? env.RELEASE_TAG;
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  assert(isReleaseTag(releaseTag), 'Validation requires a versioned release tag');
  const directSkip = ciSkipDecision({skipCi: env.SKIP_CI === 'true', reason: env.CI_SKIP_REASON || '',
    actor: env.GITHUB_ACTOR || '', mode: env.RELEASE_MODE, eventName: env.GITHUB_EVENT_NAME});
  let decision;
  if (directSkip) {
    assert.equal(sha, env.SOURCE_SHA, 'Skipped validation must use the pinned app source');
    assert.equal(releaseTag, env.RELEASE_TAG, 'Skipped validation must use the pinned release tag');
    decision = directSkip;
  } else {
    assert(token, 'Read-only GitHub token required');
    const run = await requireCommonValidation({repository, sha, releaseTag, request: async path => {
      const response = await fetch(`https://api.github.com${path}`, {headers: {
        Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json',
      }, signal: AbortSignal.timeout(30_000)});
      assert(response.ok, `Validation lookup failed (${response.status})`);
      return response.json();
    }, readArtifact: artifact => readReleaseArtifact(artifact, repository, token)});
    decision = {validationMode: run.validationMode, validationRunId: String(run.id),
      validationRunAttempt: String(run.run_attempt),
      ...(run.validationMode === 'skipped' ? {skipReason: run.skipReason, validationActor: run.validationActor} : {})};
  }
  assert(env.MOBILE_VALIDATION_PATH, 'Mobile validation evidence path is required');
  writeFileSync(env.MOBILE_VALIDATION_PATH, JSON.stringify(decision, null, 2) + '\n');
  const message = decision.validationMode === 'skipped'
    ? `Integration CI explicitly SKIPPED for ${releaseTag} (${sha}) by ${decision.validationActor}: ${JSON.stringify(decision.skipReason)}. This is not a passing test result.`
    : `Reused successful release integration validation for ${releaseTag} (${sha}), run ${decision.validationRunId}, attempt ${decision.validationRunAttempt}.`;
  console.log(message);
  if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, `${message}\n`);
}
