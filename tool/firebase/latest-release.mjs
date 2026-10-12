import assert from 'node:assert/strict';
import {appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {github, validateReceipt} from './release.mjs';
import {readReleaseArtifact} from './github-artifact.mjs';
import {writeJson} from './common.mjs';
import {productionRuns} from './release-runs.mjs';

export async function latestRelease({repository, request, readArtifact}) {
  const recent = await request(`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?branch=main&per_page=100`);
  const runs = productionRuns(recent.workflow_runs, repository);
  if (runs.some(run => run.status !== 'completed')) return {status: 'deferred'};
  const run = runs[0];
  assert(run, 'No verified production release; rollout setup is incomplete');
  assert.equal(run.conclusion, 'success', `Latest production attempt ${run.id} failed or may be partial; refusing an older receipt`);
  const result = await request(`/repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`);
  const matches = result.artifacts.filter(a => a.name === `firebase-release-${run.id}-${run.run_attempt}` && !a.expired);
  assert.equal(matches.length, 1, 'Latest production run has no verified release receipt');
  const receipt = await readArtifact(matches[0]);
  validateReceipt(receipt, {sha: run.head_sha, runId: String(run.id), attempt: String(run.run_attempt)});
  return {status: 'success', run, receipt};
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
