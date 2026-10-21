import assert from 'node:assert/strict';
import {readFileSync, appendFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {latestRelease} from './latest-release.mjs';
import {readReleaseArtifact} from './github-artifact.mjs';
import {github, requireCurrentMain, isReleaseTag, resolveReleaseTag} from './release.mjs';
import {writeJson} from './common.mjs';
import {releaseValidationFile, validateReleaseValidation} from './release-validation.mjs';
import {booleanInput} from '../release/deployment_targets.mjs';

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
export function pubspecContentChanged(before, after) {
  const withoutVersion = content => content.replace(/^version:.*(?:\r?\n|$)/m, '');
  return withoutVersion(before) !== withoutVersion(after);
}
function sourceDiff(base, sha) {
  let paths = execFileSync('git', ['diff', '--no-renames', '--name-only', base, sha, '--'], {encoding: 'utf8'}).trim().split('\n').filter(Boolean);
  const read = (ref, path) => execFileSync('git', ['show', `${ref}:${path}`], {encoding: 'utf8'});
  if (paths.includes('pubspec.yaml') && !pubspecContentChanged(read(base, 'pubspec.yaml'), read(sha, 'pubspec.yaml'))) {
    paths = paths.filter(path => path !== 'pubspec.yaml');
  }
  if (!paths.includes('firebase.json')) return paths;
  return [...paths.filter(path => path !== 'firebase.json'), ...configChanges(JSON.parse(read(base, 'firebase.json')), JSON.parse(read(sha, 'firebase.json')))];
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
export function deploymentPlan({eventName, ref, sha, event}) {
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  const releaseTag = ref?.startsWith('refs/tags/') ? ref.slice('refs/tags/'.length) : '';
  const mobileUploadRequested = booleanInput(event.inputs?.deploy_mobile, 'deploy_mobile',
    eventName === 'push' && isReleaseTag(releaseTag));
  assert(!mobileUploadRequested || isReleaseTag(releaseTag), 'Mobile follow-up requires a release tag');
  const skipInput = event.inputs?.skip_ci;
  assert([undefined, false, true, 'false', 'true'].includes(skipInput), 'skip_ci must be a boolean');
  const skip = skipInput === true || skipInput === 'true';
  const validationMode = skip ? 'skipped' : 'required';
  const rawReason = event.inputs?.skip_ci_reason;
  const reason = skip && typeof rawReason === 'string' ? rawReason.trim() : '';
  if (skip) {
    assert.equal(eventName, 'workflow_dispatch', 'CI skip requires an explicit manual dispatch');
    assert(isReleaseTag(releaseTag), 'CI skip requires a release tag');
    assert.notEqual(event.inputs?.scope, 'verify', 'Validation-only runs cannot skip CI');
    assert(reason, 'CI skip reason is required');
    assert(rawReason.length <= 2000, 'CI skip reason must be at most 2000 characters');
  }
  const policy = {validationMode, reason, mobileUploadRequested};
  if (eventName === 'workflow_dispatch') {
    const scope = event.inputs?.scope;
    assert(['full', 'backend', 'rules', 'web', 'verify'].includes(scope), 'Explicit deployment scope is required');
    assert.equal(event.inputs?.confirm_sha, sha, 'Confirm the exact source SHA');
    if (!releaseTag) {
      assert.equal(ref, 'refs/heads/main', 'Validation-only dispatch must use main');
      assert.equal(scope, 'verify', 'Production retry requires a release tag ref');
      return {scope, production: false, sha, releaseTag: '', ...policy};
    }
    assert(isReleaseTag(releaseTag), 'Production requires vX.Y.Z');
    return {scope, production: scope !== 'verify', sha, releaseTag, ...policy};
  }
  assert.equal(eventName, 'push', 'Unsupported deployment event');
  if (!releaseTag) return {scope: 'none', production: false, sha, releaseTag: '', ...policy};
  assert(isReleaseTag(releaseTag), 'Production requires vX.Y.Z');
  return {scope: 'auto', production: true, sha, releaseTag, ...policy};
}
export function releaseValidation(plan, env = process.env) {
  return validateReleaseValidation({schemaVersion: 1, kind: 'release-validation', sourceSha: plan.sha,
    releaseTag: plan.releaseTag, runId: env.GITHUB_RUN_ID, runAttempt: env.GITHUB_RUN_ATTEMPT,
    validationMode: plan.validationMode, reason: plan.reason, actor: env.GITHUB_ACTOR,
    mobileUploadRequested: plan.mobileUploadRequested});
}
export function taggedScope(backendPaths, webPaths) {
  const scope = pendingScope(['lib/__release_intent__'], backendPaths, webPaths);
  return scope === 'none' ? 'verify' : scope;
}
export async function withReleaseBaseline(plan, options, {lookup = latestRelease, diff = sourceDiff} = {}) {
  const [backend, web] = await Promise.all([
    lookup({...options, component: 'backend', allowFailed: true}),
    plan.scope === 'auto' ? lookup({...options, component: 'web', allowFailed: true}) : null,
  ]);
  const contractBaseSha = backend.receipt.sha;
  assert.match(contractBaseSha || '', /^[a-f0-9]{40}$/, 'Verified backend contract baseline required');
  const scope = plan.scope === 'auto'
    ? taggedScope(diff(contractBaseSha, plan.sha), diff(web.receipt.sha, plan.sha)) : plan.scope;
  return {...plan, scope, production: plan.production && !['verify', 'none'].includes(scope), contractBaseSha};
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  const ref = process.env.GITHUB_REF;
  const releaseTag = ref?.startsWith('refs/tags/') ? ref.slice('refs/tags/'.length) : '';
  const sha = process.env.RELEASE_SOURCE_SHA || process.env.GITHUB_SHA;
  let plan = deploymentPlan({eventName: process.env.GITHUB_EVENT_NAME, ref, sha, event});
  if (releaseTag) {
    assert.equal(await resolveReleaseTag({tag: releaseTag, repository: process.env.GITHUB_REPOSITORY, request: github}), sha,
      'Release tag moved after the workflow was triggered');
    const pubspec = execFileSync('git', ['show', `${sha}:pubspec.yaml`], {encoding: 'utf8'});
    const version = pubspec.match(/^version:\s*([^+\s]+)/m)?.[1];
    assert.equal(`v${version}`, releaseTag, 'Release tag must match pubspec version');
    await requireCurrentMain({sha, ref, tag: releaseTag, repository: process.env.GITHUB_REPOSITORY, request: github});
  }
  if (plan.scope !== 'none') {
    const options = {repository: process.env.GITHUB_REPOSITORY, request: github, ignoreRunId: process.env.GITHUB_RUN_ID,
      readArtifact: artifact => readReleaseArtifact(artifact, process.env.GITHUB_REPOSITORY, process.env.GITHUB_TOKEN)};
    plan = await withReleaseBaseline(plan, options);
  }
  assert(process.env.GITHUB_OUTPUT, 'Workflow output path is required');
  writeJson(releaseValidationFile, releaseValidation(plan));
  appendFileSync(process.env.GITHUB_OUTPUT, `scope=${plan.scope}\nsource_sha=${sha}\nrelease_tag=${releaseTag}\ncontract_base_sha=${plan.contractBaseSha || ''}\nvalidation_mode=${plan.validationMode}\nmobile_requested=${plan.mobileUploadRequested}\n`);
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY,
    `Release validation policy: **${plan.validationMode === 'skipped' ? 'CI SKIPPED — tests were not run' : 'CI required — results are checked by the release gate'}**.\n\nSource: \`${sha}\`; tag: \`${releaseTag || 'none'}\`; actor: \`${process.env.GITHUB_ACTOR}\`.\n\nMobile follow-up requested: ${plan.mobileUploadRequested}.\n${plan.reason ? `\nReason (JSON): ${JSON.stringify(plan.reason)}\n` : ''}`);
  console.log(`Verified release plan: ${plan.scope} for ${sha}; tag=${releaseTag || 'none'}; production=${plan.production}`);
}
