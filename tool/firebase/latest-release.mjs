import assert from 'node:assert/strict';
import {appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {github, validateReceipt} from './release.mjs';
import {readReleaseArtifact} from './github-artifact.mjs';
import {writeJson} from './common.mjs';
import {productionRuns} from './release-runs.mjs';

export async function latestRelease({repository, request, readArtifact, ignoreRunId, component = 'backend', allowFailed = false}) {
  // Keep the first-page URL stable; older backend releases can sit behind many
  // web/docs runs. Bound API work explicitly instead of silently stopping at 100.
  const maximumPages = 10;
  for (let page = 1; page <= maximumPages; page++) {
    const recent = await request(`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?branch=main&per_page=100${page === 1 ? '' : `&page=${page}`}`);
    for (const run of productionRuns(recent.workflow_runs, repository).filter(run => String(run.id) !== String(ignoreRunId))) {
      const jobs = await request(`/repos/${repository}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
      const production = jobs.jobs?.find(job => job.name === 'firebase-production');
      // Validation-only / documentation runs never replace a deployed receipt.
      if (!production || production.conclusion === 'skipped') continue;
      const names = component === 'web' ? ['Deploy to Firebase Hosting']
        : ['Deploy account deletion functions and data rules', 'Deploy data rules only'];
      const steps = (production.steps || []).filter(step => names.includes(step.name));
      if (steps.length && steps.every(step => step.conclusion === 'skipped')) continue;
      if (allowFailed && (run.status !== 'completed' || run.conclusion !== 'success')) continue;
      if (run.status !== 'completed') return {status: 'deferred'};
      assert.equal(run.conclusion, 'success', `Latest production attempt ${run.id} failed or may be partial; refusing an older receipt`);
      const result = await request(`/repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`);
      const matches = result.artifacts.filter(a => a.name === `firebase-release-${run.id}-${run.run_attempt}` && !a.expired);
      assert.equal(matches.length, 1, 'Latest production run has no verified release receipt');
      const receipt = await readArtifact(matches[0]);
      validateReceipt(receipt, {sha: run.head_sha, runId: String(run.id), attempt: String(run.run_attempt)});
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
