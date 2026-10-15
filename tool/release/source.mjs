import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {appendFileSync, readFileSync, writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {github} from '../firebase/release.mjs';

const shaPattern = /^[a-f0-9]{40}$/;
const versionPattern = '(?:0|[1-9]\\d*)\\.(?:0|[1-9]\\d*)\\.(?:0|[1-9]\\d*)';
const releaseTagPattern = new RegExp(`^v(${versionPattern})$`);
const developmentTagPattern = new RegExp(`^dev/v(${versionPattern})-[1-9]\\d*$`);
const git = (...args) => execFileSync('git', args, {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();

export function sourceReference(value) {
  assert(typeof value === 'string' && value.length <= 200, 'Use a versioned deployment tag');
  const tag = value.startsWith('refs/tags/') ? value.slice(10) : value;
  assert(releaseTagPattern.test(tag) || developmentTagPattern.test(tag), 'Use a dev/vX.Y.Z-N or vX.Y.Z deployment tag');
  return `refs/tags/${tag}`;
}

export function deploymentTagVersion(tag, mode) {
  assert(['qa', 'release'].includes(mode), 'Choose qa or release');
  const match = (mode === 'qa' ? developmentTagPattern : releaseTagPattern).exec(tag || '');
  assert(match, mode === 'qa' ? 'Development QA requires a dev/vX.Y.Z-N tag' : 'Production releases require a vX.Y.Z tag');
  return match[1];
}

function checkTagVersion(tag, mode, sha, runGit) {
  const version = deploymentTagVersion(tag, mode);
  const matches = [...runGit('show', `${sha}:pubspec.yaml`).matchAll(/^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$/gm)];
  assert.equal(matches.length, 1, 'Expected one app version in the selected source');
  assert.equal(version, matches[0][1], 'Deployment tag must match the selected app version');
}

export async function recheckSource({sourceSha, deploymentTag, mode, repository, request = github, runGit = git}) {
  assert.match(sourceSha || '', shaPattern, 'Missing pinned source SHA');
  assert.match(repository || '', /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/, 'Invalid repository');
  checkTagVersion(deploymentTag, mode, sourceSha, runGit);
  const base = `/repos/${repository}`;
  let object = (await request(`${base}/git/ref/tags/${deploymentTag}`)).object;
  for (let depth = 0; object?.type === 'tag' && depth < 5; depth++) {
    assert.match(object.sha || '', shaPattern, 'Invalid annotated tag object');
    object = (await request(`${base}/git/tags/${object.sha}`)).object;
  }
  assert.equal(object?.type, 'commit', 'Deployment tag must resolve to one commit');
  assert.equal(object.sha, sourceSha, 'Deployment tag moved after source selection');
  const main = await request(`${base}/compare/${sourceSha}...main`);
  assert(['ahead', 'identical'].includes(main.status) && main.merge_base_commit?.sha === sourceSha,
    'Deployment source must still be included in main');
}

export function ciSkipDecision({skipCi = false, reason = '', actor = '', mode, eventName}) {
  if (!skipCi) return null;
  assert(eventName === 'workflow_dispatch' && mode === 'release', 'CI skipping requires a manual release with a versioned tag');
  assert(typeof reason === 'string' && reason.trim() && reason.length <= 2000, 'CI skipping requires a reason (maximum 2000 characters)');
  assert(typeof actor === 'string' && actor.trim() && !/[\r\n]/.test(actor), 'CI skipping requires the requesting actor');
  return {validationMode: 'skipped', skipReason: reason.trim(), validationActor: actor};
}

export function resolveSource({sourceRef, mode, workflowRef, workflowSha, eventName, event = {}, repository,
  skipCi = false, skipReason = '', actor = '', expectedSourceSha, runGit = git}) {
  assert.match(workflowSha || '', shaPattern, 'Missing workflow source SHA');
  assert(['qa', 'release'].includes(mode), 'Choose qa or release');
  let eventSourceSha;
  if (eventName === 'push') {
    assert.equal(mode, 'qa', 'Native tag pushes only build the development QA candidate');
    assert(workflowRef?.startsWith('refs/tags/dev/'), 'Automatic QA builds require a development tag');
    sourceRef = workflowRef;
    eventSourceSha = workflowSha;
  } else if (eventName === 'workflow_run') {
    const run = event.workflow_run;
    assert(mode === 'release' && run?.status === 'completed' && run.conclusion === 'success' &&
      run.head_repository?.full_name === repository &&
      run.path === '.github/workflows/firebase-hosting-merge.yml' &&
      ['push', 'workflow_dispatch'].includes(run.event), 'Release requires this repository’s successful production CI');
    assert.match(run.head_branch || '', releaseTagPattern, 'Production CI must identify a release tag');
    assert.match(run.head_sha || '', shaPattern, 'Missing triggering release source SHA');
    sourceRef = run.head_branch;
    eventSourceSha = run.head_sha;
  } else {
    assert.equal(eventName, 'workflow_dispatch', 'Unsupported native build event');
    assert.equal(workflowRef, 'refs/heads/main', 'Run the trusted workflow from main; choose app code with source_ref');
  }
  const reference = sourceReference(sourceRef);
  const deploymentTag = reference.slice('refs/tags/'.length);
  deploymentTagVersion(deploymentTag, mode);
  const sha = runGit('rev-parse', '--verify', `${reference}^{commit}`);
  assert.match(sha, shaPattern, 'Source did not resolve to a commit');
  if (eventSourceSha) assert.equal(sha, eventSourceSha, 'Deployment tag moved after its triggering event');
  if (expectedSourceSha) assert.equal(sha, expectedSourceSha, 'Deployment tag moved after preflight');
  const ancestorOf = branch => {
    try { runGit('merge-base', '--is-ancestor', sha, branch); return true; } catch { return false; }
  };
  assert(ancestorOf('refs/remotes/origin/main'), 'Deployment source must be in main. Merge the source before signing.');
  checkTagVersion(deploymentTag, mode, sha, runGit);
  const validation = ciSkipDecision({skipCi, reason: skipReason, actor, mode, eventName});
  return {sourceSha: sha, workflowSha, sourceRef: deploymentTag, deploymentTag, ...(validation ? {validation} : {}),
    releaseMode: mode, environment: mode === 'release' ? 'production' : 'development',
    ...(mode === 'release' ? {releaseTag: deploymentTag} : {})};
}

export function validateMobileReceipt(receipt, {run, platform} = {}) {
  assert([1, 2, 3, 4].includes(receipt?.schemaVersion) && receipt.kind === 'mobile-source', 'Invalid mobile source receipt');
  for (const key of ['sourceSha', 'workflowSha']) assert.match(receipt[key] || '', shaPattern, `Invalid ${key}`);
  assert(['qa', 'release'].includes(receipt.releaseMode), 'Invalid release mode');
  assert(['ios', 'android-tv'].includes(receipt.platform), 'Invalid mobile platform');
  const environment = receipt.schemaVersion === 1 ? 'production' : receipt.environment;
  assert(['production', 'development'].includes(environment), 'Invalid mobile environment');
  const development = environment === 'development';
  assert.equal(receipt.firebaseProject, development ? 'cloud-board-development' : 'cloud-board-stationd', 'Unexpected backend environment');
  assert.equal(receipt.package, `com.sunmkim.cloudboard${development ? '.dev' : ''}`, 'Unexpected mobile app');
  if (receipt.schemaVersion === 1) assert.equal(receipt.productionBindingVerified, true, 'Artifact environment was not inspected');
  else {
    assert.equal(receipt.environmentBindingVerified, true, 'Artifact environment was not inspected');
    if (receipt.schemaVersion >= 3) assert.equal(receipt.environment,
      receipt.releaseMode === 'release' ? 'production' : 'development', 'Release mode differs from artifact environment');
    if (development) assert.equal(receipt.releaseMode, 'qa', 'Development artifacts cannot authorize release');
    if (receipt.releaseMode === 'release') assert.equal(receipt.releaseTag, `v${receipt.version}`, 'Release receipt needs its versioned release tag');
  }
  if (receipt.schemaVersion >= 4) {
    assert.equal(deploymentTagVersion(receipt.deploymentTag, receipt.releaseMode), receipt.version, 'Receipt deployment tag/version mismatch');
    assert.equal(receipt.sourceRef, receipt.deploymentTag, 'Receipt source must identify its deployment tag');
    assert.match(receipt.controlSha || '', shaPattern, 'Missing trusted control tools SHA');
    if (receipt.releaseMode === 'qa') assert.equal(receipt.releaseTag, undefined, 'Development tag cannot identify a production release');
  }
  // Older receipts predate the validation audit fields. Current writers always
  // supply them; retaining old receipts keeps installed-client history usable.
  if (receipt.validationMode !== undefined) {
    assert(['required', 'skipped', 'not_requested'].includes(receipt.validationMode), 'Invalid validation mode');
    if (receipt.validationMode === 'skipped') {
      assert.equal(receipt.releaseMode, 'release', 'Only release validation can be explicitly skipped');
      assert.equal(receipt.releaseTag, `v${receipt.version}`, 'Skipped validation requires a release tag');
      assert(typeof receipt.skipReason === 'string' && receipt.skipReason.trim(), 'Skipped validation needs its reason');
      assert(typeof receipt.validationActor === 'string' && receipt.validationActor.trim(), 'Skipped validation needs its actor');
    }
    if (receipt.releaseMode === 'qa') assert.equal(receipt.validationMode, 'not_requested', 'QA does not run release CI');
  }
  assert.match(receipt.version || '', /^\d+\.\d+\.\d+$/);
  assert.match(receipt.build || '', /^[1-9]\d*$/);
  assert.match(receipt.artifactSha256 || '', /^[a-f0-9]{64}$/);
  assert.match(receipt.runId || '', /^\d+$/);
  assert.match(receipt.runAttempt || '', /^[1-9]\d*$/);
  if (run) {
    assert.equal(receipt.workflowSha, run.head_sha, 'Receipt belongs to another workflow commit');
    assert.equal(receipt.runId, String(run.id), 'Receipt belongs to another run');
    assert.equal(receipt.runAttempt, String(run.run_attempt), 'Receipt belongs to another attempt');
  }
  if (platform) assert.equal(receipt.platform, platform);
  return receipt;
}

export async function mobileRunReceipt({run, jobs, artifacts, readArtifact, platform}) {
  const name = `mobile-source-${run.id}-${run.run_attempt}`;
  const matches = (artifacts ?? []).filter(artifact => artifact.name === name && !artifact.expired);
  const pinnedSource = jobs?.some(job => job.steps?.some(step =>
    step.name === 'Resolve and pin trusted app source' && step.conclusion === 'success'));
  if (!pinnedSource && matches.length === 0) return null; // Historical same-source workflow.
  assert(matches.length === 1 && readArtifact, 'Missing unambiguous mobile source receipt');
  return validateMobileReceipt(await readArtifact(matches[0]), {run, platform});
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const env = process.env;
  if (process.argv[2] === 'resolve') {
    const source = resolveSource({sourceRef: env.SOURCE_REF, mode: env.RELEASE_MODE,
      workflowRef: env.GITHUB_REF, workflowSha: env.GITHUB_SHA, eventName: env.GITHUB_EVENT_NAME,
      event: env.GITHUB_EVENT_PATH ? JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8')) : {}, repository: env.GITHUB_REPOSITORY,
      skipCi: env.SKIP_CI === 'true', skipReason: env.CI_SKIP_REASON || '', actor: env.GITHUB_ACTOR || '', expectedSourceSha: env.PINNED_SOURCE_SHA});
    await recheckSource({...source, mode: source.releaseMode, repository: env.GITHUB_REPOSITORY});
    const controlSha = git('rev-parse', 'HEAD');
    assert(env.GITHUB_ENV, 'GITHUB_ENV is required');
    appendFileSync(env.GITHUB_ENV, `SOURCE_SHA=${source.sourceSha}\nSOURCE_REF=${source.sourceRef}\nDEPLOYMENT_TAG=${source.deploymentTag}\nWORKFLOW_SHA=${source.workflowSha}\nCONTROL_SHA=${controlSha}\nAPP_ENVIRONMENT=${source.environment}\nRELEASE_TAG=${source.releaseTag || ''}\nAPP_PACKAGE=com.sunmkim.cloudboard${source.environment === 'development' ? '.dev' : ''}\n`);
    if (env.GITHUB_OUTPUT) appendFileSync(env.GITHUB_OUTPUT, `source_sha=${source.sourceSha}\ncontrol_sha=${controlSha}\n`);
    const validationPath = `${env.RUNNER_TEMP}/mobile-validation.json`;
    const validation = source.releaseMode === 'qa' || env.UPLOAD_REQUESTED !== 'true'
      ? {validationMode: 'not_requested'} : source.validation ?? {validationMode: 'required'};
    writeFileSync(validationPath, JSON.stringify(validation, null, 2) + '\n');
    appendFileSync(env.GITHUB_ENV, `MOBILE_VALIDATION_PATH=${validationPath}\n`);
    console.log(`Build ${source.sourceSha} (${source.releaseMode}); workflow ${source.workflowSha}`);
  } else if (process.argv[2] === 'recheck') {
    assert.equal(git('rev-parse', 'HEAD'), env.SOURCE_SHA, 'Checked out app differs from selected source');
    await recheckSource({sourceSha: env.SOURCE_SHA, deploymentTag: env.DEPLOYMENT_TAG, mode: env.RELEASE_MODE, repository: env.GITHUB_REPOSITORY});
    console.log(`Deployment tag ${env.DEPLOYMENT_TAG} still identifies ${env.SOURCE_SHA} in main.`);
  } else if (process.argv[2] === 'receipt') {
    assert.equal(git('rev-parse', 'HEAD'), env.SOURCE_SHA, 'Checked out app differs from selected source');
    const metadata = JSON.parse(readFileSync(process.argv[3], 'utf8'));
    const validation = JSON.parse(readFileSync(env.MOBILE_VALIDATION_PATH, 'utf8'));
    const receipt = validateMobileReceipt({...metadata, ...validation, schemaVersion: 4, kind: 'mobile-source',
      sourceSha: env.SOURCE_SHA, workflowSha: env.WORKFLOW_SHA, controlSha: env.CONTROL_SHA, sourceRef: env.SOURCE_REF, deploymentTag: env.DEPLOYMENT_TAG,
      releaseMode: env.RELEASE_MODE, environment: env.APP_ENVIRONMENT, releaseTag: env.RELEASE_TAG || undefined, runId: env.GITHUB_RUN_ID, runAttempt: env.GITHUB_RUN_ATTEMPT});
    writeFileSync(process.argv[4], JSON.stringify(receipt, null, 2) + '\n');
    if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY,
      `### ${receipt.releaseMode === 'qa' ? 'QA internal test build' : 'Release candidate'}\n` +
      `Deployment tag: ${receipt.deploymentTag}\n\nApp source: ${receipt.sourceSha}\n\nWorkflow source: ${receipt.workflowSha}\n\nTrusted control tools: ${receipt.controlSha}\n\n` +
      `${receipt.platform} ${receipt.version} (${receipt.build}) · ${receipt.firebaseProject}\n\n` +
      `Integration validation: ${receipt.validationMode}${receipt.skipReason ? ` — explicitly skipped by ${receipt.validationActor}: ${JSON.stringify(receipt.skipReason)}` : ''}.\n\n` +
      'Build/signature checks are not a claim that full integration CI or store review passed.\n');
  } else throw new Error('Use resolve, recheck or receipt');
}
