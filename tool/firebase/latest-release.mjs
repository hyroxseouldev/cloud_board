import assert from 'node:assert/strict';
import {appendFileSync} from 'node:fs';
import {github, validateReceipt} from './release.mjs';
import {readReleaseArtifact} from './github-artifact.mjs';
import {writeJson} from './common.mjs';
const repository = process.env.GITHUB_REPOSITORY;
assert.equal(repository, 'hyroxseouldev/cloud_board');
const recent = await github(`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?branch=main&event=push&per_page=30`);
if (recent.workflow_runs.some(r => r.status !== 'completed')) {
  writeJson('build/release/observation.json', {status: 'deferred', reason: 'Production validation/deployment is in progress', checkedAt: new Date().toISOString()});
  if (process.env.GITHUB_ENV) appendFileSync(process.env.GITHUB_ENV, 'FIREBASE_DEPLOYMENT_PENDING=true\n');
  console.log('Deployment is in progress; defer drift observation without interfering with the deployment queue.');
  process.exit(0);
}
const data = await github(`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?branch=main&event=push&status=success&per_page=30`);
const run = data.workflow_runs.filter(r => r.head_repository?.full_name === repository && r.head_branch === 'main' && r.event === 'push')
  .sort((a, b) => b.id - a.id)[0];
assert(run, 'No verified production release; rollout setup is incomplete');
const result = await github(`/repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`);
const matches = result.artifacts.filter(a => a.name === `firebase-release-${run.id}-${run.run_attempt}` && !a.expired);
assert.equal(matches.length, 1, 'Latest successful run has no verified release receipt');
const receipt = await readReleaseArtifact(matches[0], repository, process.env.GITHUB_TOKEN);
validateReceipt(receipt, {sha: run.head_sha, runId: String(run.id), attempt: String(run.run_attempt)});
writeJson('build/release/release.json', receipt); writeJson('build/release/manifest.json', receipt.manifest);
console.log(`Loaded verified release ${run.id}, attempt ${run.run_attempt}, commit ${run.head_sha}.`);
