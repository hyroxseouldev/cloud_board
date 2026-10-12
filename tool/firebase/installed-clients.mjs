import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

export const installedWorkflows = [
  {file: 'testflight-main.yml', step: 'Upload to TestFlight', platforms: ['ios']},
  {file: 'google-play-main.yml', step: 'Upload mobile and TV bundle to internal testing', platforms: ['android', 'tv']},
  {file: 'firebase-hosting-merge.yml', step: 'Deploy to Firebase Hosting', platforms: ['web']},
];
export function requireRegisteredUpload(clients, upload, platforms) {
  for (const platform of platforms) assert(clients.some(client => client.sourceCommit === upload.head_sha &&
    client.platforms.includes(platform) && client.releases?.some(release => release.platform === platform &&
      String(release.workflowRunId) === String(upload.id))),
  `Latest installed ${platform} source/run has no frozen contract: ${upload.head_sha} / ${upload.id}. Register the released client before changing its server contract.`);
}
export async function verifyInstalledClients({clients, repository, request, currentRunId}) {
  assert.match(repository || '', /^[\w.-]+\/[\w.-]+$/);
  const result = [];
  for (const workflow of installedWorkflows) {
    const {workflow_runs: runs} = await request(`/repos/${repository}/actions/workflows/${workflow.file}/runs?branch=main&per_page=30`);
    let found;
    for (const run of runs ?? []) {
      if (String(run.id) === String(currentRunId) || run.status !== 'completed' || run.head_branch !== 'main' ||
          !['push', 'workflow_dispatch'].includes(run.event)) continue;
      const {jobs} = await request(`/repos/${repository}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
      // An upload can succeed before a later cleanup step fails. Track the upload
      // step, not just the workflow conclusion. Backend-only repairs don't count.
      if (!jobs?.some(job => job.steps?.some(step => step.name === workflow.step && step.conclusion === 'success'))) continue;
      found = run; break;
    }
    assert(found, `Cannot verify the latest installed client for ${workflow.file}; inspect deployment history.`);
    requireRegisteredUpload(clients, found, workflow.platforms);
    result.push({platforms: workflow.platforms, runId: String(found.id), sha: found.head_sha});
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
    repository: process.env.GITHUB_REPOSITORY, currentRunId: process.env.GITHUB_RUN_ID}), null, 2));
}
