import assert from 'node:assert/strict';
import {validateReceipt} from '../firebase/release.mjs';
import {validateMobileReceipt} from './source.mjs';

export const ledgerBranch = 'cloudboard-deployment-receipts';
export const ledgerPath = 'direct-deployments.json';
export const repository = 'hyroxseouldev/cloud_board';
const sha = /^[a-f0-9]{40}$/;
export function validateAttempt(value) {
  assert.equal(value?.schemaVersion, 1);
  assert.equal(value.kind, 'direct-deployment');
  assert.match(value.id || '', /^[1-9]\d*$/);
  assert.match(value.sourceSha || '', sha);
  assert(['development', 'production'].includes(value.environment));
  assert.equal(value.project, value.environment === 'development' ? 'cloud-board-development' : 'cloud-board-stationd');
  assert.match(value.version || '', /^\d+\.\d+\.\d+$/);
  if (value.environment === 'production') assert.equal(value.tag, `v${value.version}`);
  assert(['web', 'rules', 'backend', 'functions', 'ios', 'android'].includes(value.scope));
  assert(['running', 'success', 'failed'].includes(value.status));
  assert(Number.isFinite(Date.parse(value.startedAt)));
  assert(Array.isArray(value.steps));
  assert(value.steps.every(s => typeof s.id === 'string' && ['running', 'success', 'failed'].includes(s.status)));
  assert.equal(new Set(value.steps.map(s => s.id)).size, value.steps.length);
  if (value.status !== 'running') assert(Number.isFinite(Date.parse(value.completedAt)));
  if (value.status === 'success') assert(value.steps.length && value.steps.every(s => s.status === 'success'));
  if (value.release) {
    assert.equal(value.environment, 'production');
    validateReceipt(value.release, {sha: value.sourceSha, runId: value.id, attempt: '1'});
    assert.equal(value.release.scope, value.scope, 'Direct receipt scope mismatch');
    assert.equal(value.release.manifest.releaseTag, value.tag, 'Direct receipt tag mismatch');
    assert(value.steps.some(s => s.id === 'verify-receipt' && s.status === 'success'), 'Missing successful receipt verification stage');
  }
  if (value.mobile) {
    validateMobileReceipt(value.mobile);
    assert.equal(value.mobile.sourceSha, value.sourceSha);
    assert.equal(value.mobile.environment, value.environment);
    assert.equal(value.mobile.runId, value.id);
    assert.equal(value.mobile.platform, value.scope === 'ios' ? 'ios' : 'android-tv');
    assert.equal(value.mobile.version, value.version);
    assert(value.steps.some(s => s.id === 'inspect-artifact' && s.status === 'success'), 'Missing artifact inspection stage');
  }
  return value;
}
export function validateLedger(value) {
  assert.equal(value?.schemaVersion, 1);
  assert.equal(value.kind, 'direct-deployment-ledger');
  assert(Array.isArray(value.attempts) && value.attempts.length <= 2000, 'Archive the ledger with retained history before 2000 attempts');
  value.attempts.forEach(validateAttempt);
  assert.equal(new Set(value.attempts.map(a => a.id)).size, value.attempts.length);
  return value;
}
export async function readLedger(request, repo = repository) {
  assert.equal(repo, repository);
  const refs = await request(`/repos/${repo}/git/matching-refs/heads/${ledgerBranch}`);
  assert(Array.isArray(refs));
  if (!refs.some(ref => ref.ref === `refs/heads/${ledgerBranch}`)) return null;
  const file = await request(`/repos/${repo}/contents/${ledgerPath}?ref=${ledgerBranch}`);
  assert.equal(file.encoding, 'base64');
  return {sha: file.sha, ledger: validateLedger(JSON.parse(Buffer.from(file.content, 'base64').toString()))};
}
export async function writeLedger(request, state, ledger) {
  validateLedger(ledger);
  try { return await request(`/repos/${repository}/contents/${ledgerPath}`, {method: 'PUT', body: {
    branch: ledgerBranch, message: `release receipt: ${ledger.attempts.at(-1).id} ${ledger.attempts.at(-1).status}`,
    content: Buffer.from(JSON.stringify(ledger, null, 2) + '\n').toString('base64'), ...(state?.sha ? {sha: state.sha} : {}),
  }}); } catch {
    // The PUT may have reached GitHub even if its response was lost. Read the
    // latest document once; accept only the complete intended content, never
    // replay a stale CAS or overwrite a concurrent owner's attempt.
    const observed = await readLedger(request);
    assert(observed && JSON.stringify(observed.ledger) === JSON.stringify(ledger),
      'Receipt write is unconfirmed or conflicted; inspect latest ledger before recovery');
    return {content: {sha: observed.sha}};
  }
}
export async function beginAttempt(request, attempt) {
  validateAttempt(attempt);
  let state = await readLedger(request);
  assert(!state?.ledger.attempts.some(a => a.status === 'running'), 'A direct deployment is pending; inspect/reconcile it before starting another');
  if (!state) {
    // Atomic ref creation is also the first-run lock. A concurrent creator fails closed.
    await request(`/repos/${repository}/git/refs`, {method: 'POST', body: {ref: `refs/heads/${ledgerBranch}`, sha: attempt.sourceSha}});
    state = {ledger: {schemaVersion: 1, kind: 'direct-deployment-ledger', attempts: []}};
  }
  const ledger = {...state.ledger, attempts: [...state.ledger.attempts, attempt]};
  const result = await writeLedger(request, state, ledger);
  return {sha: result.content.sha, ledger: structuredClone(ledger)};
}
export async function updateAttempt(request, state, attempt) {
  const previous = state.ledger.attempts.at(-1);
  assert(previous?.id === attempt.id && previous.status === 'running', 'Only the pending owner may update its attempt; terminal history is immutable');
  for (const key of ['sourceSha', 'environment', 'project', 'scope', 'startedAt']) assert.equal(attempt[key], previous[key], 'Attempt identity changed');
  const ledger = {...state.ledger, attempts: state.ledger.attempts.map(a => a.id === attempt.id ? attempt : a)};
  assert(ledger.attempts.some(a => a.id === attempt.id));
  const result = await writeLedger(request, state, ledger);
  return {sha: result.content.sha, ledger: structuredClone(ledger)};
}
export function latestDirect(ledger, {component = 'backend', environment = 'production', ignoreRunId, attemptOnly = false} = {}) {
  const scopes = component === 'backend' ? ['backend', 'rules', 'functions'] : [component];
  const attempt = [...validateLedger(ledger).attempts].reverse().find(a => a.environment === environment && scopes.includes(a.scope) && a.id !== String(ignoreRunId));
  if (!attempt) return null;
  const run = {id: attempt.id, run_attempt: 1, head_sha: attempt.sourceSha, head_branch: attempt.tag,
    html_url: `https://github.com/${repository}/blob/${ledgerBranch}/${ledgerPath}`, direct: true};
  if (attemptOnly) return {status: 'attempt', run};
  if (attempt.status === 'running') return {status: 'deferred', run};
  assert.equal(attempt.status, 'success', 'Latest direct deployment failed or may be partial; reconcile before using an older receipt');
  assert(attempt.release, 'Deployment command finished but full backend/rules verification is unavailable; do not infer compatibility');
  return {status: 'success', run, receipt: attempt.release};
}
export function directUploads(ledger) {
  return validateLedger(ledger).attempts.filter(a => a.environment === 'production' &&
    a.steps.some(s => s.id === (a.scope === 'web' ? 'deploy' : 'upload') && s.status === 'success'));
}
