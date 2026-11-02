import assert from 'node:assert/strict';
import {latestRelease} from '../firebase/latest-release.mjs';

// User explicitly requested this upload after being told the deployed server's
// TV smoke failed. This is a scoped approval, never a successful test receipt.
const approved = {
  repository: 'hyroxseouldev/cloud_board',
  sha: 'dc86f8aa023352c06998fae7f989aa47abbffad7',
  run: '41475618259', attempt: 1, artifact: 13157528051,
  digest: 'sha256:7ed4c4b035bd3c66128967803eb1d9102c5ecf0c28d42799f0e52fce4afca4ae',
  fingerprint: '072b0ab70606271d1f44b6700b90f4e1e36ccea0757e86f80d778c4338903ee7',
  expires: '2026-11-03T16:00:00Z',
};

export async function approvedTestflightBackend({env, repository, sha, mobile, fingerprint, request, readMember, now = Date.now()}) {
  assert.equal(repository, approved.repository);
  assert.equal(sha, approved.sha);
  assert.equal(fingerprint, approved.fingerprint);
  assert.equal(mobile, true);
  assert.equal(env.BACKEND_EXCEPTION_RUN, approved.run);
  assert.equal(env.GITHUB_EVENT_NAME, 'workflow_dispatch');
  assert.equal(env.RELEASE_MODE, 'release');
  assert.equal(env.RELEASE_TAG, 'v2.0.7');
  assert.equal(env.IOS_BUNDLE_ID, 'com.sunmkim.cloudboard');
  assert.equal(env.SKIP_CI, 'true');
  assert(now < Date.parse(approved.expires), 'The one-time upload approval expired');
  const comparison = await request(`/repos/${repository}/compare/${sha}...main`);
  assert(['ahead', 'identical'].includes(comparison.status) && comparison.merge_base_commit?.sha === sha);
  const {run} = await latestRelease({repository, request, attemptOnly: true});
  assert.equal(String(run.id), approved.run, 'A newer production attempt requires a new decision');
  assert.equal(run.run_attempt, approved.attempt);
  assert.equal(run.head_sha, sha);
  assert.equal(run.head_branch, 'v2.0.7');
  assert.equal(run.status, 'completed');
  assert.equal(run.conclusion, 'failure');
  const {jobs} = await request(`/repos/${repository}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
  const production = jobs.find(job => job.name === 'firebase-production');
  for (const name of ['Deploy account deletion functions and data rules', 'Verify deployed rules']) {
    assert(production?.steps.some(step => step.name === name && step.conclusion === 'success'), `${name} must have succeeded`);
  }
  assert(production.steps.some(step => step.name === 'Verify client save, image and TV permissions' && step.conclusion === 'failure'));
  const {artifacts} = await request(`/repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`);
  const artifact = artifacts.find(item => item.id === approved.artifact);
  assert(artifact && !artifact.expired && artifact.name === `firebase-attempt-${run.id}-1`);
  assert.equal(artifact.digest, approved.digest);
  const [manifest, smoke, rules] = await Promise.all(['manifest.json', 'smoke.json', 'live-rules.json'].map(member => readMember(artifact, member)));
  assert.equal(manifest.sha, sha);
  assert.equal(manifest.runId, approved.run);
  assert.equal(manifest.attempt, '1');
  assert.equal(manifest.scope, 'backend');
  assert.equal(manifest.backendFingerprint, fingerprint);
  assert.equal(rules.status, 'success');
  assert.equal(smoke.status, 'failure');
  assert.equal(smoke.phase, 'tv');
  assert.equal(smoke.error, 'PERMISSION_DENIED');
  assert.equal(smoke.cleanup, 'success');
  assert.deepEqual(smoke.checks, ['workout', 'storage']);
  return {...run, backendReference: {runId: approved.run, sha, fingerprint, approval: {
    kind: 'user-approved-testflight-exception', expiresAt: approved.expires,
    reason: 'User explicitly requested iOS 2.0.7 TestFlight upload and deferred smoke-script repair after disclosure of this failure.',
    artifactId: approved.artifact, artifactDigest: approved.digest,
    smokeStatus: 'failure', smokePhase: smoke.phase, smokeError: smoke.error, cleanup: smoke.cleanup,
  }}};
}
