import assert from 'node:assert/strict';
import {readFileSync, appendFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {latestRelease} from './latest-release.mjs';
import {readReleaseArtifact} from './github-artifact.mjs';
import {github, requireCurrentMain} from './release.mjs';

export function changedScope(paths) {
  const backend = paths.some(p => /^(functions\/(src|certificates)\/|functions\/package(?:-lock)?\.json$|firebase\.json$)/.test(p));
  const rules = paths.some(p => /^(firestore\.rules|firestore\.indexes\.json|database\.rules\.json|storage\.rules)$/.test(p));
  const web = paths.some(p => /^(lib\/|assets\/|web\/|config\/brand\.json$|pubspec\.(yaml|lock)$|\.fvmrc$|firebase\.json$)/.test(p));
  return web && (backend || rules) ? 'full' : web ? 'web' : backend ? 'backend' : rules ? 'rules' : 'none';
}
export function configChanges(before, after) {
  const changed = key => JSON.stringify(before[key]) !== JSON.stringify(after[key]);
  return [
    ...(changed('hosting') ? ['web/__firebase_config__'] : []),
    ...(changed('functions') ? ['functions/src/__firebase_config__'] : []),
    ...(changed('firestore') || changed('database') || changed('storage') ? ['firestore.rules'] : []),
    ...(changed('flutter') ? ['lib/__firebase_config__'] : []),
  ];
}
function sourceDiff(base, sha) {
  const paths = execFileSync('git', ['diff', '--name-only', base, sha, '--'], {encoding: 'utf8'}).trim().split('\n').filter(Boolean);
  if (!paths.includes('firebase.json')) return paths;
  const config = ref => JSON.parse(execFileSync('git', ['show', `${ref}:firebase.json`], {encoding: 'utf8'}));
  return [...paths.filter(path => path !== 'firebase.json'), ...configChanges(config(base), config(sha))];
}
// A later push must carry forward product changes from a failed/skipped
// deployment, while a documentation/workflow-only push never deploys production.
export function pendingScope(currentPaths, backendPaths, webPaths) {
  if (changedScope(currentPaths) === 'none') return 'none';
  const server = changedScope(backendPaths);
  const web = ['web', 'full'].includes(changedScope(webPaths));
  const backend = ['backend', 'full'].includes(server);
  const rules = server === 'rules';
  return web && (backend || rules) ? 'full' : web ? 'web' : backend ? 'backend' : rules ? 'rules' : 'none';
}
export function deploymentPlan({eventName, ref, sha, event, changedFiles = []}) {
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  if (eventName === 'workflow_dispatch') {
    assert.equal(ref, 'refs/heads/main', 'Manual production repair requires main');
    assert.equal(event.inputs?.confirm_sha, sha, 'Confirm the exact current main SHA');
    assert(['full', 'backend', 'rules', 'web', 'verify'].includes(event.inputs?.scope), 'Explicit deployment scope is required');
    return {scope: event.inputs.scope, production: true, sha};
  }
  assert(['push', 'pull_request'].includes(eventName), 'Unsupported deployment event');
  const production = eventName === 'push' && ref === 'refs/heads/main';
  return {scope: changedScope(changedFiles), production, sha};
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  const sha = process.env.GITHUB_SHA;
  const base = event.pull_request?.base?.sha || event.before;
  let changedFiles = [];
  if (process.env.GITHUB_EVENT_NAME !== 'workflow_dispatch') {
    assert.match(base || '', /^(?!0{40}$)[a-f0-9]{40}$/, 'A trustworthy changed-file base is required');
    changedFiles = sourceDiff(base, sha);
  }
  const plan = deploymentPlan({eventName: process.env.GITHUB_EVENT_NAME, ref: process.env.GITHUB_REF, sha, event, changedFiles});
  if (plan.production && process.env.GITHUB_EVENT_NAME === 'push' && plan.scope !== 'none') {
    const options = {repository: process.env.GITHUB_REPOSITORY, request: github, ignoreRunId: process.env.GITHUB_RUN_ID, allowFailed: true,
      readArtifact: artifact => readReleaseArtifact(artifact, process.env.GITHUB_REPOSITORY, process.env.GITHUB_TOKEN)};
    const [backend, web] = await Promise.all([latestRelease(options), latestRelease({...options, component: 'web'})]);
    const diff = source => sourceDiff(source, sha);
    plan.scope = pendingScope(changedFiles, diff(backend.receipt.sha), diff(web.receipt.sha));
  }
  if (plan.production && plan.scope !== 'none') await requireCurrentMain({sha: plan.sha, ref: process.env.GITHUB_REF, repository: process.env.GITHUB_REPOSITORY, request: github});
  assert(process.env.GITHUB_OUTPUT, 'Workflow output path is required');
  appendFileSync(process.env.GITHUB_OUTPUT, `scope=${plan.scope}\n`);
  console.log(`Verified deployment plan: ${plan.scope} for ${plan.sha}; production=${plan.production}`);
}
