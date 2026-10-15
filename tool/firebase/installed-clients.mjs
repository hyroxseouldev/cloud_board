import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {readReleaseArtifact} from './github-artifact.mjs';
import {mobileRunReceipt} from '../release/source.mjs';

export const installedWorkflows = [
  {file: 'testflight-main.yml', step: 'Upload to TestFlight', platforms: ['ios']},
  {file: 'google-play-main.yml', step: 'Upload mobile and TV bundle to internal testing', platforms: ['android', 'tv']},
  {file: 'firebase-hosting-merge.yml', step: 'Deploy to Firebase Hosting', platforms: ['web']},
];
export function requireRegisteredUpload(clients, upload, platforms) {
  const sourceSha = upload.sourceSha ?? upload.head_sha;
  for (const platform of platforms) assert(clients.some(client => client.sourceCommit === sourceSha &&
    client.platforms.includes(platform) && client.releases?.some(release => release.platform === platform &&
      String(release.workflowRunId) === String(upload.id) &&
      (!upload.artifactSha256 || release.artifactSha256 === upload.artifactSha256))),
  `Latest installed ${platform} source/run has no frozen contract: ${sourceSha} / ${upload.id}. Register the installed client (including production-connected QA) before changing its server contract.`);
}
export async function verifyInstalledClients({clients, repository, request, currentRunId, readArtifact}) {
  assert.match(repository || '', /^[\w.-]+\/[\w.-]+$/);
  const result = [];
  for (const workflow of installedWorkflows) {
    let found;
    for (let page = 1; page <= 10 && !found; page++) {
      const {workflow_runs: runs} = await request(`/repos/${repository}/actions/workflows/${workflow.file}/runs?per_page=100&page=${page}`);
      for (const run of runs ?? []) {
      if (String(run.id) === String(currentRunId) || run.status !== 'completed' || (run.head_branch !== 'main' && !/^v\d+\.\d+\.\d+$/.test(run.head_branch || '')) ||
          !['push', 'workflow_dispatch', 'workflow_run'].includes(run.event)) continue;
      const {jobs} = await request(`/repos/${repository}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
      // An upload can succeed before a later cleanup step fails. Track the upload
      // step, not just the workflow conclusion. Backend-only repairs don't count.
      if (!jobs?.some(job => job.steps?.some(step => step.name === workflow.step && step.conclusion === 'success'))) continue;
      if (workflow.platforms[0] !== 'web') {
        const pinnedSource = jobs.some(job => job.steps?.some(step =>
          step.name === 'Resolve and pin trusted app source' && step.conclusion === 'success'));
        if (pinnedSource) {
          const {artifacts} = await request(`/repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`);
          const receipt = await mobileRunReceipt({run, jobs, artifacts, readArtifact,
            platform: workflow.platforms[0] === 'ios' ? 'ios' : 'android-tv'});
          if (receipt.environment === 'development') continue;
          found = {...run, sourceSha: receipt.sourceSha, artifactSha256: receipt.artifactSha256, releaseMode: receipt.releaseMode};
        }
      }
      found ??= run; break;
      }
      if ((runs ?? []).length < 100) break;
    }
    assert(found, `Cannot verify the latest installed client for ${workflow.file}; inspect deployment history.`);
    requireRegisteredUpload(clients, found, workflow.platforms);
    result.push({platforms: workflow.platforms, runId: String(found.id), sha: found.sourceSha ?? found.head_sha,
      ...(found.sourceSha ? {workflowSha: found.head_sha, releaseMode: found.releaseMode} : {})});
  }
  return result;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  assert(process.env.GITHUB_TOKEN, 'Read-only GitHub token required');
  const request = async path => {
    const response = await fetch(`https://api.github.com${path}`, {headers: {
      authorization: `Bearer ${process.env.GITHUB_TOKEN}`, accept: 'application/vnd.github+json',
    }});
    assert(response.ok, `Release inventory lookup failed (${response.status})`);
    return response.json();
  };
  const {clients} = JSON.parse(readFileSync('tool/firebase/supported-clients.json', 'utf8'));
  console.log(JSON.stringify(await verifyInstalledClients({clients, request,
    readArtifact: artifact => readReleaseArtifact(artifact, process.env.GITHUB_REPOSITORY, process.env.GITHUB_TOKEN),
    repository: process.env.GITHUB_REPOSITORY, currentRunId: process.env.GITHUB_RUN_ID}), null, 2));
}
