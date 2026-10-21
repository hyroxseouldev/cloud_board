import assert from 'node:assert/strict';
import {appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {github, validateReceipt, isReleaseTag} from './release.mjs';
import {readReleaseArtifact} from './github-artifact.mjs';
import {writeJson} from './common.mjs';
import {productionRuns} from './release-runs.mjs';

function cancelledBeforeRunnerAssignment(job) {
  // A cancelled dependency can emit a completed job row without ever assigning
  // a runner. Require positive API evidence; missing metadata is not a no-op.
  return job.status === 'completed' && job.conclusion === 'cancelled' &&
    Array.isArray(job.steps) && job.steps.length === 0 &&
    ['runner_id', 'runner_name', 'runner_group_id', 'runner_group_name']
      .every(key => Object.hasOwn(job, key) && job[key] === null) &&
    typeof job.started_at === 'string' && Number.isFinite(Date.parse(job.started_at)) &&
    job.completed_at === job.started_at;
}

export async function latestRelease({repository, request, readArtifact, ignoreRunId, component = 'backend', allowFailed = false, attemptOnly = false}) {
  // Search both release tags and historical main deployments; older backend
  // releases can sit behind many web/docs runs. Bound API work explicitly instead of silently stopping at 100.
  const maximumPages = 10;
  const names = component === 'web' ? ['Deploy to Firebase Hosting']
    : ['Deploy account deletion functions and data rules', 'Deploy data rules only'];
  for (let page = 1; page <= maximumPages; page++) {
    const recent = await request(`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?per_page=100${page === 1 ? '' : `&page=${page}`}`);
    for (const candidate of productionRuns(recent.workflow_runs, repository).filter(run => String(run.id) !== String(ignoreRunId))) {
      assert(Number.isSafeInteger(candidate.run_attempt) && candidate.run_attempt > 0 && candidate.run_attempt <= 100,
        'Production attempt history is too large or invalid');
      let selected;
      // A retry that fails before deployment cannot erase an earlier partial
      // write. Only look back when this attempt did not deploy the component.
      for (let attempt = candidate.run_attempt; attempt >= 1; attempt--) {
        const jobs = await request(`/repos/${repository}/actions/runs/${candidate.id}/attempts/${attempt}/jobs?per_page=100`);
        assert(Array.isArray(jobs.jobs) && (jobs.total_count ?? jobs.jobs.length) <= 100,
          'Production job history is missing or truncated');
        const production = jobs.jobs.find(job => job.name === 'firebase-production');
        // Validation-only / documentation runs never replace a deployed receipt.
        if (!production || production.conclusion === 'skipped') continue;
        // Continue through earlier attempts: an unstarted retry must not hide
        // a previous partial write by this same workflow run.
        if (cancelledBeforeRunnerAssignment(production)) continue;
        const steps = (production.steps || []).filter(step => names.includes(step.name));
        assert(attempt === candidate.run_attempt || steps.length, 'Previous production deployment steps are unavailable');
        if (steps.length && steps.every(step => step.conclusion === 'skipped')) continue;
        // A newer tag waiting for the production lock has not written yet, but
        // a previous attempt of that same run may already have changed service.
        if (attemptOnly && !steps.some(step => step.conclusion !== 'skipped' &&
          (step.conclusion || step.status === 'in_progress' || step.started_at))) continue;
        selected = {run: {...candidate, run_attempt: attempt}, production};
        break;
      }
      if (!selected) continue;
      const {run, production} = selected;
      if (attemptOnly) return {status: 'attempt', run};
      if (allowFailed && (run.status !== 'completed' || run.conclusion !== 'success' || production.conclusion !== 'success')) continue;
      if (run.status !== 'completed') return {status: 'deferred'};
      assert(run.conclusion === 'success' && production.conclusion === 'success',
        `Latest production attempt ${run.id} failed or may be partial; refusing an older receipt`);
      const result = await request(`/repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`);
      const matches = result.artifacts.filter(a => a.name === `firebase-release-${run.id}-${run.run_attempt}` && !a.expired);
      assert.equal(matches.length, 1, 'Latest production run has no verified release receipt');
      const receipt = await readArtifact(matches[0]);
      validateReceipt(receipt, {sha: run.head_sha, runId: String(run.id), attempt: String(run.run_attempt)});
      if (isReleaseTag(run.head_branch)) assert.equal(receipt.manifest.releaseTag, run.head_branch, 'Receipt release tag mismatch');
      const scope = receipt.scope || 'full';
      if (component === 'backend' ? scope === 'web' : !['web', 'full'].includes(scope)) continue;
      return {status: 'success', run, receipt};
    }

    if (recent.workflow_runs.length < 100) break;
    assert(page < maximumPages, 'Release history search exceeded 1000 runs; choose an explicit verified backend release');
  }
  throw new Error('No verified production release; rollout setup is incomplete');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const repository = process.env.GITHUB_REPOSITORY;
  assert.equal(repository, 'hyroxseouldev/cloud_board');
  const result = await latestRelease({repository, request: github,
    readArtifact: artifact => readReleaseArtifact(artifact, repository, process.env.GITHUB_TOKEN)});
  if (result.status === 'deferred') {
    writeJson('build/release/observation.json', {status: 'deferred', reason: 'Production validation/deployment is in progress', checkedAt: new Date().toISOString()});
    if (process.env.GITHUB_ENV) appendFileSync(process.env.GITHUB_ENV, 'FIREBASE_DEPLOYMENT_PENDING=true\n');
    console.log('Deployment is in progress; defer drift observation without interfering with the deployment queue.');
  } else {
    writeJson('build/release/release.json', result.receipt); writeJson('build/release/manifest.json', result.receipt.manifest);
    console.log(`Loaded verified release ${result.run.id}, attempt ${result.run.run_attempt}, commit ${result.run.head_sha}.`);
  }
}
