import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {billingAccount} from '../src/billing.js';
import {refreshDueEntitlements, runDailyMaintenance} from '../src/scheduled-maintenance.js';
import {retrySupportNotifications} from '../src/support-tickets.js';

// Fixed isolated demo namespace; never allow credentials to reach a live DB.
for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_DATABASE_EMULATOR_HOST']) {
  assert.match(process.env[key] ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
}
const projectId = 'demo-cloudboard-maintenance';
const app = initializeApp({projectId, databaseURL: `http://${process.env.FIREBASE_DATABASE_EMULATOR_HOST}?ns=${projectId}`});
const db = getFirestore(app), realtime = getDatabase(app), now = Date.now();
const [databaseHost, databasePort] = process.env.FIREBASE_DATABASE_EMULATOR_HOST.split(':');
const env = await initializeTestEnvironment({projectId, database: {host: databaseHost, port: Number(databasePort),
  rules: readFileSync(new URL('../../database.rules.json', import.meta.url), 'utf8')}});
try {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  const cleared = await fetch(`http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
  assert.equal(cleared.ok, true);
  await realtime.ref().remove();
  const grant = {source: 'admin', managed: true, plan: 'legacy', status: 'active',
    validUntilMs: now + 3600000, maxActiveDisplays: 4, displayLimit: 4};
  for (const uid of ['free', 'trial', 'admin', 'expired', 'revoked', 'future']) {
    if (['admin', 'expired', 'revoked'].includes(uid)) {
      await db.doc(`subscriptionEntitlements/${uid}`).set({...grant,
        ...(uid === 'expired' ? {validUntilMs: now - 1} : {}),
        ...(uid === 'revoked' ? {status: 'revoked'} : {})});
    }
    if (uid === 'free') await db.doc(`users/${uid}/onboarding/progress`).set({phoneVerified: true});
    if (uid === 'trial') await db.doc(`onboardingTrials/${uid}`).set({endsAtMs: now + 3600000});
    await billingAccount(db, realtime, uid);
    await db.doc(`billingAccounts/${uid}`).update({nextCheckAtMs: uid === 'future' ? now + 3600000 : now - 1});
  }
  assert.equal(await refreshDueEntitlements({db, realtime, now}), 5);
  const access = async uid => (await realtime.ref(`subscriptionAccess/${uid}`).get()).val();
  assert.equal((await access('free')).canStartClass, true);
  assert.equal((await access('free')).plan, 'free');
  assert.equal((await access('trial')).plan, 'premium');
  assert.equal((await access('admin')).maxActiveDisplays, 4);
  for (const uid of ['expired', 'revoked']) assert.equal((await access(uid)).canStartClass, false);
  assert.equal(await access('future'), null);
  const before = await access('admin');
  assert.equal(await refreshDueEntitlements({db, realtime, now}), 0);
  assert.deepEqual(await access('admin'), before, 'repeat invocation does not rewrite grants');

  await db.doc('users/cleanup').set({});
  await realtime.ref('users/cleanup').set({activeSession: {id: 'active'}, playbackSnapshots: {
    active: {_storedAtMs: now - 8 * 86400000}, stale: {_storedAtMs: now - 8 * 86400000},
    recent: {_storedAtMs: now - 86400000},
  }});
  await db.doc('onboardingPhoneChallenges/expired').set({expiresAtMs: now - 2 * 86400000});
  await db.doc('onboardingPhoneChallenges/grace').set({expiresAtMs: now - 1000});
  await db.doc('onboardingSmsLimits/expired').set({expiresAt: Timestamp.fromMillis(now - 1000)});
  const ticket = {notificationStatus: 'retrying', message: 'preserve'};
  const outbox = {status: 'retrying', attempts: 0, nextAttemptAtMs: now - 1};
  await db.doc('users/cleanup/supportTickets/kept').set(ticket);
  await db.doc('supportNotificationOutbox/kept').set(outbox);
  await db.doc('users/cleanup/supportUploads/submitted').set({submitted: true, cleanupAtMs: now - 1, path: 'keep'});
  await runDailyMaintenance({db, realtime, now, bucket: {file: () => assert.fail('submitted attachment must be retained')}});
  assert.deepEqual(Object.keys((await realtime.ref('users/cleanup/playbackSnapshots').get()).val()).sort(), ['active', 'recent']);
  assert.equal((await db.doc('onboardingPhoneChallenges/expired').get()).exists, false);
  assert.equal((await db.doc('onboardingPhoneChallenges/grace').get()).exists, true);
  assert.equal((await db.doc('onboardingSmsLimits/expired').get()).exists, false);
  assert.equal((await db.doc('users/cleanup/supportUploads/submitted').get()).exists, true);
  assert.equal(await retrySupportNotifications({db, config: {}, projectId, send: null, now}), 0);
  assert.deepEqual((await db.doc('supportNotificationOutbox/kept').get()).data(), outbox);
  assert.deepEqual((await db.doc('users/cleanup/supportTickets/kept').get()).data(), ticket);
  console.log('PASS maintenance emulator: due/Free/trial/admin/expired/revoked/RTDB/idempotency, daily TTL and active snapshot, submitted attachment and disabled outbox preservation');
} finally {await env.cleanup(); await deleteApp(app);}
