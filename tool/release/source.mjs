import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {appendFileSync, readFileSync, writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

const shaPattern = /^[a-f0-9]{40}$/;
const git = (...args) => execFileSync('git', args, {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();

export function sourceReference(value) {
  assert(typeof value === 'string' && value.length <= 200 && !/[\s~^:?*\[\\]/.test(value) &&
    !value.includes('..') && !value.includes('@{') && !value.startsWith('-'), 'Use a repository branch, tag or full commit SHA');
  if (shaPattern.test(value)) return value;
  if (['main', 'develop'].includes(value) || /^release\/[A-Za-z0-9._/-]+$/.test(value)) return `refs/remotes/origin/${value}`;
  const tag = value.startsWith('refs/tags/') ? value.slice(10) : value;
  assert(/^[A-Za-z0-9][A-Za-z0-9._/-]*$/.test(tag) && !tag.endsWith('/') && !tag.endsWith('.lock'), 'Invalid source reference');
  return `refs/tags/${tag}`;
}

export function ciSkipDecision({skipCi = false, reason = '', actor = '', mode, eventName}) {
  if (!skipCi) return null;
  assert(eventName === 'workflow_dispatch' && mode === 'release', 'CI skipping requires a manual release with a versioned tag');
  assert(typeof reason === 'string' && reason.trim() && reason.length <= 2000, 'CI skipping requires a reason (maximum 2000 characters)');
  assert(typeof actor === 'string' && actor.trim() && !/[\r\n]/.test(actor), 'CI skipping requires the requesting actor');
  return {validationMode: 'skipped', skipReason: reason.trim(), validationActor: actor};
}

export function resolveSource({sourceRef, mode, workflowRef, workflowSha, eventName, event = {}, repository,
  skipCi = false, skipReason = '', actor = '', runGit = git}) {
  assert.match(workflowSha || '', shaPattern, 'Missing workflow source SHA');
  assert(['qa', 'release'].includes(mode), 'Choose qa or release');
  let reference;
  if (eventName === 'push') {
    assert.equal(workflowRef, 'refs/heads/main', 'Automatic QA builds require main');
    assert.equal(mode, 'qa', 'Main pushes only build the QA candidate');
    reference = workflowSha;
  } else if (eventName === 'workflow_run') {
    const run = event.workflow_run;
    assert(mode === 'release' && run?.status === 'completed' && run.conclusion === 'success' &&
      run.head_repository?.full_name === repository &&
      run.path === '.github/workflows/firebase-hosting-merge.yml' &&
      ['push', 'workflow_dispatch'].includes(run.event), 'Release requires this repository’s successful production CI');
    assert.match(run.head_branch || '', /^v\d+\.\d+\.\d+$/, 'Production CI must identify a release tag');
    sourceRef = run.head_branch;
    reference = sourceReference(sourceRef);
    assert.equal(runGit('rev-parse', '--verify', `${reference}^{commit}`), run.head_sha, 'Release tag moved after CI');
  } else {
    assert.equal(eventName, 'workflow_dispatch', 'Unsupported native build event');
    assert.equal(workflowRef, 'refs/heads/main', 'Run the trusted workflow from main; choose app code with source_ref');
    reference = sourceReference(sourceRef);
  }
  const sha = runGit('rev-parse', '--verify', `${reference}^{commit}`);
  assert.match(sha, shaPattern, 'Source did not resolve to a commit');
  const ancestorOf = branch => {
    try { runGit('merge-base', '--is-ancestor', sha, branch); return true; } catch { return false; }
  };
  assert(ancestorOf('refs/remotes/origin/main') ||
    (mode === 'qa' && ancestorOf('refs/remotes/origin/develop')),
  'Release source must be in main; QA source must be in main or develop. Merge the source before signing.');
  let releaseTag;
  if (mode === 'release') {
    releaseTag = sourceRef?.replace(/^refs\/tags\//, '');
    assert.match(releaseTag || '', /^v\d+\.\d+\.\d+$/, 'Production releases require a vX.Y.Z tag');
    const version = runGit('show', `${sha}:pubspec.yaml`).match(/^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$/m)?.[1];
    assert.equal(releaseTag, `v${version}`, 'Release tag must match the selected app version');
  }
  const validation = ciSkipDecision({skipCi, reason: skipReason, actor, mode, eventName});
  return {sourceSha: sha, workflowSha, sourceRef: sourceRef || workflowRef, ...(validation ? {validation} : {}),
    releaseMode: mode, environment: mode === 'release' ? 'production' : 'development', ...(releaseTag ? {releaseTag} : {})};
}

export function validateMobileReceipt(receipt, {run, platform} = {}) {
  assert([1, 2, 3].includes(receipt?.schemaVersion) && receipt.kind === 'mobile-source', 'Invalid mobile source receipt');
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
    if (receipt.schemaVersion === 3) assert.equal(receipt.environment,
      receipt.releaseMode === 'release' ? 'production' : 'development', 'Release mode differs from artifact environment');
    if (development) assert.equal(receipt.releaseMode, 'qa', 'Development artifacts cannot authorize release');
    if (receipt.releaseMode === 'release') assert.equal(receipt.releaseTag, `v${receipt.version}`, 'Release receipt needs its versioned release tag');
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
      skipCi: env.SKIP_CI === 'true', skipReason: env.CI_SKIP_REASON || '', actor: env.GITHUB_ACTOR || ''});
    assert(env.GITHUB_ENV, 'GITHUB_ENV is required');
    appendFileSync(env.GITHUB_ENV, `SOURCE_SHA=${source.sourceSha}\nSOURCE_REF=${source.sourceRef}\nWORKFLOW_SHA=${source.workflowSha}\nAPP_ENVIRONMENT=${source.environment}\nRELEASE_TAG=${source.releaseTag || ''}\nAPP_PACKAGE=com.sunmkim.cloudboard${source.environment === 'development' ? '.dev' : ''}\n`);
    const validationPath = `${env.RUNNER_TEMP}/mobile-validation.json`;
    const validation = source.releaseMode === 'qa' || env.UPLOAD_REQUESTED !== 'true'
      ? {validationMode: 'not_requested'} : source.validation ?? {validationMode: 'required'};
    writeFileSync(validationPath, JSON.stringify(validation, null, 2) + '\n');
    appendFileSync(env.GITHUB_ENV, `MOBILE_VALIDATION_PATH=${validationPath}\n`);
    console.log(`Build ${source.sourceSha} (${source.releaseMode}); workflow ${source.workflowSha}`);
  } else if (process.argv[2] === 'receipt') {
    assert.equal(git('rev-parse', 'HEAD'), env.SOURCE_SHA, 'Checked out app differs from selected source');
    const metadata = JSON.parse(readFileSync(process.argv[3], 'utf8'));
    const validation = JSON.parse(readFileSync(env.MOBILE_VALIDATION_PATH, 'utf8'));
    const receipt = validateMobileReceipt({...metadata, ...validation, schemaVersion: 3, kind: 'mobile-source',
      sourceSha: env.SOURCE_SHA, workflowSha: env.WORKFLOW_SHA, sourceRef: env.SOURCE_REF,
      releaseMode: env.RELEASE_MODE, environment: env.APP_ENVIRONMENT, releaseTag: env.RELEASE_TAG || undefined, runId: env.GITHUB_RUN_ID, runAttempt: env.GITHUB_RUN_ATTEMPT});
    writeFileSync(process.argv[4], JSON.stringify(receipt, null, 2) + '\n');
    if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY,
      `### ${receipt.releaseMode === 'qa' ? 'QA internal test build' : 'Release candidate'}\n` +
      `App source: ${receipt.sourceSha}\n\nWorkflow source: ${receipt.workflowSha}\n\n` +
      `${receipt.platform} ${receipt.version} (${receipt.build}) · ${receipt.firebaseProject}\n\n` +
      `Integration validation: ${receipt.validationMode}${receipt.skipReason ? ` — explicitly skipped by ${receipt.validationActor}: ${JSON.stringify(receipt.skipReason)}` : ''}.\n\n` +
      'Build/signature checks are not a claim that full integration CI or store review passed.\n');
  } else throw new Error('Use resolve or receipt');
}
