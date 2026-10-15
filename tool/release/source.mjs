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

export function resolveSource({sourceRef, mode, workflowRef, workflowSha, eventName, runGit = git}) {
  assert.equal(eventName, 'workflow_dispatch', 'Native builds are manual');
  assert.equal(workflowRef, 'refs/heads/main', 'Run the trusted workflow from main; choose app code with source_ref');
  assert.match(workflowSha || '', shaPattern, 'Missing workflow source SHA');
  assert(['qa', 'release'].includes(mode), 'Choose qa or release');
  const reference = sourceReference(sourceRef);
  const sha = runGit('rev-parse', '--verify', `${reference}^{commit}`);
  assert.match(sha, shaPattern, 'Source did not resolve to a commit');
  const ancestorOf = branch => {
    try { runGit('merge-base', '--is-ancestor', sha, branch); return true; } catch { return false; }
  };
  // A tag or SHA must still identify reviewed main/develop history. Merely
  // creating a tag must not authorize arbitrary fork code with signing secrets.
  assert(ancestorOf('refs/remotes/origin/main') ||
    (mode === 'qa' && ancestorOf('refs/remotes/origin/develop')),
  'Release source must be in main; QA source must be in main or develop. Merge the source before signing.');
  return {sourceSha: sha, workflowSha, sourceRef, releaseMode: mode};
}

export function validateMobileReceipt(receipt, {run, platform} = {}) {
  assert(receipt?.schemaVersion === 1 && receipt.kind === 'mobile-source', 'Invalid mobile source receipt');
  for (const key of ['sourceSha', 'workflowSha']) assert.match(receipt[key] || '', shaPattern, `Invalid ${key}`);
  assert(['qa', 'release'].includes(receipt.releaseMode), 'Invalid release mode');
  assert(['ios', 'android-tv'].includes(receipt.platform), 'Invalid mobile platform');
  assert.equal(receipt.firebaseProject, 'cloud-board-stationd', 'Unexpected backend environment');
  assert.equal(receipt.package, 'com.sunmkim.cloudboard', 'Unexpected mobile app');
  assert.equal(receipt.productionBindingVerified, true, 'Artifact environment was not inspected');
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
      workflowRef: env.GITHUB_REF, workflowSha: env.GITHUB_SHA, eventName: env.GITHUB_EVENT_NAME});
    assert(env.GITHUB_ENV, 'GITHUB_ENV is required');
    appendFileSync(env.GITHUB_ENV, `SOURCE_SHA=${source.sourceSha}\nWORKFLOW_SHA=${source.workflowSha}\n`);
    console.log(`Build ${source.sourceSha} (${source.releaseMode}); workflow ${source.workflowSha}`);
  } else if (process.argv[2] === 'receipt') {
    assert.equal(git('rev-parse', 'HEAD'), env.SOURCE_SHA, 'Checked out app differs from selected source');
    const metadata = JSON.parse(readFileSync(process.argv[3], 'utf8'));
    const receipt = validateMobileReceipt({...metadata, schemaVersion: 1, kind: 'mobile-source',
      sourceSha: env.SOURCE_SHA, workflowSha: env.WORKFLOW_SHA, sourceRef: env.SOURCE_REF,
      releaseMode: env.RELEASE_MODE, runId: env.GITHUB_RUN_ID, runAttempt: env.GITHUB_RUN_ATTEMPT});
    writeFileSync(process.argv[4], JSON.stringify(receipt, null, 2) + '\n');
    if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY,
      `### ${receipt.releaseMode === 'qa' ? 'QA internal test build' : 'Release candidate'}\n` +
      `App source: ${receipt.sourceSha}\n\nWorkflow source: ${receipt.workflowSha}\n\n` +
      `${receipt.platform} ${receipt.version} (${receipt.build}) · ${receipt.firebaseProject}\n\n` +
      'Build/signature checks are not a claim that full integration CI or store review passed.\n');
  } else throw new Error('Use resolve or receipt');
}
