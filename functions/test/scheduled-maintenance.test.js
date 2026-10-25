import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {schedulePolicy, runMaintenanceTasks, refreshDueEntitlements, cleanupOnboarding} from '../src/scheduled-maintenance.js';
import {retrySupportNotifications, approvedSupportRecipient} from '../src/support-tickets.js';

test('provider schedules require explicit enablement; mail requires delivery and secret intent', () => {
  assert.deepEqual(schedulePolicy({}), {apple: false, google: false, support: false});
  assert.equal(schedulePolicy({SUPPORT_EMAIL_DELIVERY_ENABLED: 'true'}).support, false);
  assert.deepEqual(schedulePolicy({APP_STORE_RECONCILIATION_ENABLED: 'true',
    GOOGLE_PLAY_RECONCILIATION_ENABLED: 'true', SUPPORT_EMAIL_DELIVERY_ENABLED: 'true',
    SUPPORT_EMAIL_SECRETS_ENABLED: 'true'}), {apple: true, google: true, support: true});
});

test('one failed or delayed cleanup cannot prevent independent cleanup; failure is retryable and sanitized', async () => {
  const completed = [], logs = [];
  let release;
  const delayed = new Promise(resolve => {release = resolve;});
  const result = runMaintenanceTasks({
    broken: () => {throw new Error('private-account-and-secret');},
    delayed: () => delayed,
    onboarding: async () => {completed.push('onboarding');},
    uploads: async () => {completed.push('uploads');},
  }, entry => logs.push(entry));
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(completed, ['onboarding', 'uploads']);
  release();
  await assert.rejects(result, /scheduled-maintenance-failed:1/);
  assert.equal(logs.filter(entry => entry.status === 'completed').length, 3);
  assert.doesNotMatch(JSON.stringify(logs), /private-account|secret/);
});

test('due accounts retain <= deadline and 100 limit; a failing account does not skip another', async () => {
  const calls = [], refreshed = [], realtime = {};
  const db = {collection(name) {calls.push(name); return this;},
    where(...args) {calls.push(args); return this;}, limit(count) {calls.push(count); return this;},
    async get() {return {size: 3, docs: [{id: 'valid'}, {id: 'failed'}, {id: 'expired'}]};}};
  await assert.rejects(refreshDueEntitlements({db, realtime, now: 1234,
    refresh: async (receivedDb, receivedRealtime, uid) => {
      assert.equal(receivedDb, db); assert.equal(receivedRealtime, realtime);
      refreshed.push(uid); if (uid === 'failed') throw new Error('unavailable');
    }}), /entitlement-refresh-failed:1/);
  assert.deepEqual(calls, ['billingAccounts', ['nextCheckAtMs', '<=', 1234], 100]);
  assert.deepEqual(refreshed, ['valid', 'failed', 'expired']);
});

test('onboarding cleanup retains its one-day challenge grace and timestamp expiry, stops at deadline', async () => {
  const calls = [], now = Date.now();
  const db = {collection(name) {calls.push(name); return this;},
    where(field, op, cutoff) {calls.push([field, op, cutoff.toMillis?.() ?? cutoff]); return this;},
    limit(count) {assert.equal(count, 400); return this;},
    async get() {return {size: 0, docs: []};}, batch() {return {commit: async () => {}};}};
  await cleanupOnboarding({db, now});
  assert.deepEqual(calls, ['onboardingPhoneChallenges', ['expiresAtMs', '<', now - 86400000],
    'onboardingSmsLimits', ['expiresAt', '<', now]]);
  await assert.rejects(cleanupOnboarding({db, now, deadlineMs: 0}), /maintenance-deadline/);
});

test('disabled or incomplete mail performs zero outbox reads or writes; enabling resumes due polling', async () => {
  const config = {enabled: true, provider: 'resend', recipientEmail: approvedSupportRecipient, fromEmail: 'support@example.test'};
  const forbiddenDb = {collection() {assert.fail('disabled mail queried outbox');}};
  for (const options of [{config, send: null}, {config: {}, send: async () => {}},
    {config: {...config, enabled: false}, send: async () => {}}]) {
    assert.equal(await retrySupportNotifications({db: forbiddenDb, projectId: 'demo-maintenance', ...options}), 0);
  }
  let reads = 0;
  const db = {collection(name) {assert.equal(name, 'supportNotificationOutbox'); reads++; return this;},
    where() {return this;}, limit(n) {assert.equal(n, 20); return this;},
    async get() {return {size: 0, docs: []};}};
  assert.equal(await retrySupportNotifications({db, config, projectId: 'demo-maintenance', send: async () => {}}), 0);
  assert.equal(reads, 1);
});

function metadata(projectId, extraEnv = {}) {
  return JSON.parse(execFileSync(process.execPath, ['--input-type=module', '-e',
    `const m=await import('./src/index.js'); console.log(JSON.stringify(Object.fromEntries(Object.entries(m).map(([n,f])=>[n,f.__endpoint]))));`],
  {cwd: new URL('..', import.meta.url), encoding: 'utf8', env: {PATH: process.env.PATH, GCLOUD_PROJECT: projectId, ...extraEnv}}));
}
test('actual production discovery has four schedules, bounded retries and all purchase/recovery APIs', () => {
  const endpoints = metadata('cloud-board-stationd');
  assert.deepEqual(Object.keys(endpoints).filter(n => endpoints[n].scheduleTrigger && !endpoints[n].omit).sort(),
    ['cleanupDailyMaintenance', 'recoverTemplateJobs', 'refreshBillingEntitlements', 'retryAccountDeletions'].sort());
  assert.equal(endpoints.cleanupDailyMaintenance.timeoutSeconds, 540);
  assert.equal(endpoints.cleanupDailyMaintenance.scheduleTrigger.retryConfig.retryCount, 3);
  for (const name of ['cloudboardBilling', 'cloudboardPlayBilling', 'googlePlayNotifications',
    'processGooglePlayNotification', 'processAppStoreNotification', 'cloudboardSubmitSupportTicket']) assert(endpoints[name]);
  for (const name of ['cleanupPlaybackSnapshots', 'cleanupOnboardingVerification', 'cleanupClientDiagnostics', 'cleanupSupportTicketUploads']) {
    assert.equal(endpoints[name].omit, true);
  }
});

test('store scheduler opt-in is discoverable without restoring duplicate account scans', () => {
  const endpoints = metadata('cloud-board-stationd', {APP_STORE_RECONCILIATION_ENABLED: 'true', GOOGLE_PLAY_RECONCILIATION_ENABLED: 'true'});
  assert.equal(endpoints.reconcileAppStoreBilling.omit, false);
  assert.equal(endpoints.reconcileGooglePlayBilling.omit, false);
});

test('development discovery excludes billing refresh and retains three schedules', () => {
  const endpoints = metadata('cloud-board-development');
  assert.deepEqual(Object.keys(endpoints).filter(n => endpoints[n].scheduleTrigger && !endpoints[n].omit).sort(),
    ['cleanupDailyMaintenance', 'recoverTemplateJobs', 'retryAccountDeletions'].sort());
});
