import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {GoogleAuth} from 'google-auth-library';
import {targets, validateReceipt} from '../../tool/firebase/release.mjs';
import {readJson, writeJson} from '../../tool/firebase/common.mjs';

export function summarizeDiagnostics(entries, receipt) {
  const start = Date.parse(receipt.completedAt);
  assert(Number.isFinite(start));
  const groups = new Map();
  let delayedBeforeRelease = 0;
  for (const entry of entries) {
    const event = entry.jsonPayload || {}, context = event.context || {};
    if (event.message !== 'client_diagnostic') continue;
    const occurred = Date.parse(event.occurredAt);
    if (!Number.isFinite(occurred)) continue;
    if (occurred < start) { delayedBeforeRelease++; continue; }
    // Only bounded, known diagnostic dimensions; never include raw message, uid,
    // stack, URLs, workout contents, email or bearer token in this report.
    const clean = value => String(value || 'unknown').replace(/[^A-Za-z0-9._+-]/g, '').slice(0, 80);
    const item = {action: clean(context.action), code: clean(context.firebaseCode || event.code), platform: clean(context.platform), version: clean(context.version), build: clean(context.build)};
    const key = JSON.stringify(item), previous = groups.get(key);
    groups.set(key, {...item, count: (previous?.count || 0) + 1});
  }
  return {status: groups.size ? 'errors-observed' : 'no-errors-observed', dataMeaning: 'Error counts only; absence of errors is not evidence of successful saves.',
    sha: receipt.sha, releaseAt: receipt.completedAt, delayedBeforeRelease, groups: [...groups.values()]};
}
export function validateSaveAlert(policies, channels) {
  const matching = policies.filter(p => p.userLabels?.managed_by === 'cloudboard' && p.userLabels?.purpose === 'workout-save');
  assert.equal(matching.length, 1, 'Exactly one managed save alert is required');
  const policy = matching[0]; assert.equal(policy.enabled, true, 'Save alert disabled');
  const filter = policy.conditions?.[0]?.conditionMatchedLog?.filter || '';
  for (const key of ['client_diagnostic', 'workout.save', 'workout.duplicate']) assert(filter.includes(key), `Alert filter missing ${key}`);
  assert(policy.notificationChannels?.length > 0, 'Missing alert receiver');
  for (const id of policy.notificationChannels) {
    const channel = channels.find(c => c.name === id);
    assert(channel?.enabled, 'Alert receiver disabled or missing');
    assert.notEqual(channel.verificationStatus, 'UNVERIFIED', 'Alert receiver needs verification');
  }
  return {status: 'configured', policy: policy.name, receivers: policy.notificationChannels.length,
    delivery: 'not-verified-by-configuration-read'};
}
export async function inspectHealth(receipt, request, now = Date.now()) {
  validateReceipt(receipt, receipt);
  const since = new Date(Math.max(Date.parse(receipt.completedAt), now - 2 * 60 * 60_000)).toISOString();
  const parent = `projects/${targets.project}`;
  async function list(kind) {
    const values = []; let pageToken;
    do {
      const page = await request('GET', `https://monitoring.googleapis.com/v3/${parent}/${kind}${pageToken ? `?pageToken=${encodeURIComponent(pageToken)}` : ''}`);
      values.push(...(page[kind] || [])); pageToken = page.nextPageToken;
    } while (pageToken);
    return values;
  }
  const alert = validateSaveAlert(await list('alertPolicies'), await list('notificationChannels'));
  const entries = []; let pageToken; let truncated = false;
  for (let page = 0; page < 10; page++) {
    const data = await request('POST', 'https://logging.googleapis.com/v2/entries:list', {resourceNames: [parent],
      filter: `jsonPayload.message="client_diagnostic" AND timestamp>="${since}" AND severity>=ERROR`,
      orderBy: 'timestamp desc', pageSize: 100, pageToken});
    entries.push(...(data.entries || [])); pageToken = data.nextPageToken;
    if (!pageToken) break;
    truncated = page === 9;
  }
  const diagnostics = {...summarizeDiagnostics(entries, receipt), receivedSince: since, truncated};
  if (truncated && diagnostics.status === 'no-errors-observed') diagnostics.status = 'incomplete';
  return {format: 1, checkedAt: new Date(now).toISOString(), alert, diagnostics};
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const client = await new GoogleAuth({scopes: ['https://www.googleapis.com/auth/cloud-platform']}).getClient();
    const result = await inspectHealth(readJson(process.argv[2] || 'build/release/release.json'), async (method, url, data) =>
      (await client.request({method, url, data, timeout: 30_000})).data);
    writeJson('build/release/health.json', result);
    console.log(`Save alert ${result.alert.status}; diagnostics ${result.diagnostics.status}.`);
    if (result.diagnostics.status !== 'no-errors-observed') process.exitCode = 1;
  } catch {
    writeJson('build/release/health.json', {format: 1, status: 'unknown', checkedAt: new Date().toISOString(), reason: 'Monitoring configuration or diagnostic collection could not be verified'});
    console.error('Release health is unknown; check monitoring access and existing alert configuration.');
    process.exitCode = 1;
  }
}
