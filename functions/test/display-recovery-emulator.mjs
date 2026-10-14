import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {ref, set, get, update, remove, serverTimestamp, onDisconnect} from 'firebase/database';
import {initializeApp} from 'firebase-admin/app';
import {getDatabase} from 'firebase-admin/database';
import {mutateDisplayConnection} from '../src/display-recovery.js';
import {emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';

const projectId = requireDemo('demo-cloudboard-recovery');
const env = await initializeTestEnvironment({projectId, database: {
  ...emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST),
  rules: readFileSync(new URL('../../database.rules.json', import.meta.url), 'utf8'),
}});
const adminApp = initializeApp({projectId, databaseURL: `https://${projectId}.firebaseio.com`}, 'recovery-contracts');
const admin = getDatabase(adminApp);
const owner = env.authenticatedContext('owner', {firebase: {sign_in_provider: 'password'}}).database();
const tv = env.authenticatedContext('tv-user', {firebase: {sign_in_provider: 'anonymous'}}).database();
const foreign = env.authenticatedContext('foreign').database();
const anonymous = env.unauthenticatedContext().database();
const auth = (uid, provider) => ({uid, token: {firebase: {sign_in_provider: provider}}});
const ownerAuth = auth('owner', 'password'), tvAuth = auth('tv-user', 'anonymous');
const devicePath = 'users/owner/devices/tv';
const requestPath = 'users/owner/displayRecovery/tv/current';
const info = {deviceId: 'tv', operationId: 'operation-1', connectionId: 'connection-1', expectedPairingCode: '123456', appVersion: '1.2.0', appBuild: '220'};
function seed() {
  return {users: {owner: {devices: {tv: {id: 'tv', displayUid: 'tv-user', mode: 'display',
    paired: true, pairingCode: '123456', pairedAtMs: 1, recoveryProtocol: 1,
    online: true, lastSeenAtMs: Date.now()}, other: {id: 'other', displayUid: 'other-tv', mode: 'display',
    paired: true, online: true, lastSeenAtMs: Date.now()}}, activeSession: {id: 'session-1', revision: 7, status: 'playing'}}},
    displayAccess: {'tv-user': {ownerId: 'owner', deviceId: 'tv', pairingCode: '123456', pairedAtMs: 1}},
    legacyPilotAccess: {owner: {validUntilMs: Date.now() + 60000}}};
}
const invoke = (actor, action, patch = {}) => mutateDisplayConnection(admin, actor, action, {...info, ...patch});
try {
  await admin.ref().set(seed());
  await assertSucceeds(get(ref(tv, requestPath))); // Subscription can start before the first owner request.
  // This identity erasure was allowed by the old blanket pilot exception.
  await assertFails(update(ref(tv, devicePath), {displayUid: null}));
  await assertFails(update(ref(owner, devicePath), {displayUid: null}));
  await assertFails(update(ref(tv, devicePath), {paired: false}));
  await assertFails(remove(ref(tv, devicePath)));
  await assertFails(update(ref(tv, 'users/owner/devices/other'), {online: false}));
  // Existing clients retain ordinary updates, metadata and onDisconnect payloads.
  await assertSucceeds(update(ref(tv, devicePath), {online: false, lastSeenAtMs: serverTimestamp()}));
  await assertSucceeds(update(ref(tv, devicePath), {online: true, lastSeenAtMs: serverTimestamp(), currentSessionId: 'session-1', acknowledgedRevision: 7}));
  await assertSucceeds(update(ref(owner, devicePath), {name: 'Renamed', zoneName: 'Main'}));

  await admin.ref(`${devicePath}/displayUid`).remove();
  await assertFails(get(ref(tv, 'users/owner/displayPreparation/request')));
  await assertFails(update(ref(tv, devicePath), {displayUid: 'tv-user'}));
  const disconnectBeforeRepair = onDisconnect(ref(tv, `${devicePath}/presence/before-repair`));
  await assertSucceeds(disconnectBeforeRepair.set({online: false, lastSeenAtMs: serverTimestamp()}));
  await assertFails(set(ref(tv, `${devicePath}/presence/before-repair`), {online: true, lastSeenAtMs: serverTimestamp()}));
  await disconnectBeforeRepair.cancel();
  const result = await invoke(tvAuth, 'verify');
  assert.equal(result.status, 'repaired');
  assert.equal((await admin.ref(`${devicePath}/displayUid`).get()).val(), 'tv-user');
  await assertSucceeds(get(ref(tv, 'users/owner/displayPreparation/request')));
  await assertFails(get(ref(owner, 'displayConnectionAudit')));
  await assertFails(get(ref(tv, 'displayConnectionAudit')));
  await assertFails(set(ref(owner, 'displayConnectionAudit/forged'), {serverAtMs: 1}));
  await assertFails(set(ref(owner, `${devicePath}/connectionVerification/verifiedAtMs`), Date.now()));

  // Three reconnects use independent slots; a late disconnect can only touch
  // its old slot and cannot mark the current connection offline.
  for (let i = 1; i <= 3; i++) {
    const connectionId = `connection-${i}`;
    await invoke(tvAuth, 'verify', {connectionId, operationId: connectionId});
    await assertSucceeds(update(ref(tv, devicePath), {presenceProtocol: 1, currentConnectionId: connectionId,
      [`presence/${connectionId}`]: {online: true, lastSeenAtMs: serverTimestamp()}}));
    if (i > 1) await assertSucceeds(update(ref(tv, `${devicePath}/presence/connection-${i - 1}`), {online: false, lastSeenAtMs: serverTimestamp()}));
    assert.equal((await get(ref(owner, `${devicePath}/currentConnectionId`))).val(), connectionId);
    assert.equal((await get(ref(owner, `${devicePath}/presence/${connectionId}/online`))).val(), true);
  }
  await assertFails(update(ref(tv, devicePath), {currentConnectionId: 'connection-1'}));
  await assertFails(update(ref(tv, `${devicePath}/connectionVerification`), {connectionId: 'forged'}));
  await assertSucceeds(set(ref(tv, `${devicePath}/preparationHealth`), {
    stage: 'response_write', code: 'permission_denied', attempt: 1, checkedAtMs: serverTimestamp(), requestId: 'prepare-test'}));
  await assertFails(set(ref(tv, `${devicePath}/preparationHealth`), {
    stage: 'response_write', code: 'raw Bearer secret', attempt: 1, checkedAtMs: serverTimestamp()}));

  const request = await invoke(ownerAuth, 'request'); assert.equal(request.status, 'requested');
  await assertSucceeds(get(ref(owner, requestPath))); await assertSucceeds(get(ref(tv, requestPath)));
  for (const db of [owner, tv, foreign, anonymous]) await assertFails(set(ref(db, requestPath), {...request, status: 'succeeded'}));
  for (const db of [foreign, anonymous]) await assertFails(get(ref(db, requestPath)));
  await invoke(tvAuth, 'report', {status: 'received'});
  await invoke(tvAuth, 'report', {status: 'recovering'});
  await assert.rejects(invoke(tvAuth, 'report', {status: 'succeeded', sessionId: 'session-1', revision: 6}), e => e.details?.code === 'latest_session_changed');
  const succeeded = await invoke(tvAuth, 'report', {status: 'succeeded', sessionId: 'session-1', revision: 7});
  assert.equal(succeeded.status, 'succeeded'); assert.equal(typeof succeeded.verifiedAtMs, 'number');
  const runningClass = (await admin.ref('users/owner/activeSession').get()).val();
  await invoke(ownerAuth, 'unpair', {operationId: 'unpair-1'});
  assert.deepEqual((await admin.ref('users/owner/activeSession').get()).val(), runningClass);
  assert.equal((await admin.ref('users/owner/devices/other').get()).exists(), true);
  await assertFails(update(ref(tv, devicePath), {id: 'tv', mode: 'display', paired: true, displayUid: 'tv-user', online: true, lastSeenAtMs: serverTimestamp()}));
  await assert.rejects(invoke(tvAuth, 'verify'), e => e.details?.code === 'connection_missing');
  await assertFails(get(ref(tv, requestPath)));
  // A late installed Admin server write cannot resurrect effective access.
  const previous = seed();
  await admin.ref(devicePath).set(previous.users.owner.devices.tv);
  await admin.ref('displayAccess/tv-user').set(previous.displayAccess['tv-user']);
  await assertFails(get(ref(tv, 'users/owner/activeSession')));
  await assertFails(get(ref(tv, 'users/owner/devices')));
  await assertFails(get(ref(tv, requestPath)));
  await assertFails(update(ref(tv, devicePath), {online: true, lastSeenAtMs: serverTimestamp()}));
  await assert.rejects(invoke(ownerAuth, 'request', {operationId: 'revoked-request'}), e => e.details?.code === 'device_unpaired');
  await assert.rejects(invoke(tvAuth, 'verify'), e => e.details?.code === 'device_unpaired');

  // A supported owner-authenticated legacy TV may still issue and claim its
  // own pairing code. It cannot turn an ordinary heartbeat into registration.
  await admin.ref().set({legacyPilotAccess: {owner: {validUntilMs: Date.now() + 60000}}});
  await assertSucceeds(update(ref(owner, 'users/owner'), {
    'pairingCodes/654321': {code: '654321', deviceId: 'old-tv', expiresAtMs: Date.now() + 10000, claimed: false},
    'devices/old-tv': {id: 'old-tv', mode: 'display', online: false, lastSeenAtMs: 1, pairingCode: '654321'},
  }));
  await assertSucceeds(update(ref(owner, 'users/owner'), {'pairingCodes/654321/claimed': true,
    'devices/old-tv/paired': true, 'devices/old-tv/pairedAtMs': serverTimestamp()}));
  await assertSucceeds(update(ref(owner, 'users/owner/devices/old-tv'), {online: true, lastSeenAtMs: serverTimestamp()}));
  console.log('PASS: identity-erasure regression, authenticated missing-UID repair, legacy compatibility, 3 reconnect generations, restricted diagnostics/audit, manual stages and latest revision, revoke/late response, single-TV isolation');
} finally { await adminApp.delete(); await env.cleanup(); }
