import assert from 'node:assert/strict';
import {readFileSync, appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {github, requireCurrentMain} from './release.mjs';

export function deploymentPlan({eventName, ref, sha, event}) {
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  if (eventName === 'workflow_dispatch') {
    assert.equal(ref, 'refs/heads/main', 'Manual production repair requires main');
    assert.equal(event.inputs?.confirm_sha, sha, 'Confirm the exact current main SHA');
    assert(['full', 'backend', 'rules'].includes(event.inputs?.scope), 'Explicit deployment scope is required');
    return {scope: event.inputs.scope, production: true, sha};
  }
  assert(['push', 'pull_request'].includes(eventName), 'Unsupported deployment event');
  const production = eventName === 'push' && ref === 'refs/heads/main';
  const scope = production && event.head_commit?.message?.includes('[backend only]') ? 'backend' : 'full';
  return {scope, production, sha};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const plan = deploymentPlan({eventName: process.env.GITHUB_EVENT_NAME, ref: process.env.GITHUB_REF,
    sha: process.env.GITHUB_SHA, event: JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'))});
  if (plan.production) await requireCurrentMain({sha: plan.sha, ref: process.env.GITHUB_REF, repository: process.env.GITHUB_REPOSITORY, request: github});
  assert(process.env.GITHUB_OUTPUT, 'Workflow output path is required');
  appendFileSync(process.env.GITHUB_OUTPUT, `scope=${plan.scope}\n`);
  console.log(`Verified deployment plan: ${plan.scope} for ${plan.sha}; production=${plan.production}`);
}
