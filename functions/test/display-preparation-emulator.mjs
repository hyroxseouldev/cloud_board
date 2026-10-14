import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {ref, set, get, update, runTransaction} from 'firebase/database';
import {emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';
const projectId = requireDemo('demo-cloudboard-preparation');
const env = await initializeTestEnvironment({projectId, database: {
  ...emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST),
  rules: readFileSync(new URL('../../database.rules.json', import.meta.url), 'utf8'),
}});
const owner = env.authenticatedContext('owner', {firebase: {sign_in_provider: 'password'}}).database();
const tv = env.authenticatedContext('tv-user', {firebase: {sign_in_provider: 'anonymous'}}).database();
const foreign = env.authenticatedContext('foreign').database();
const path = 'users/owner/displayPreparation';
const request = {schemaVersion: 1, sessionId: 'prepare-session-1', revision: 1,
  manifestHash: 'a'.repeat(64), workoutId: 'workout', expiresAtMs: Date.now() + 60000,
  requiredProtocol: 5, targets: {tv: true}, images: ['https://example.invalid/image.png'],
  imageCount: 1, sounds: ['videoBeep']};
const ready = {sessionId: request.sessionId, revision: 1, manifestHash: request.manifestHash,
  status: 'ready', checkedAtMs: Date.now(), imageCount: 1, audioReady: true};
try {
  await env.clearDatabase();
  await env.withSecurityRulesDisabled(async c => {
    await set(ref(c.database(), 'users/owner/devices/tv'), {id: 'tv', mode: 'display',
      online: true, lastSeenAtMs: Date.now(), paired: true, displayUid: 'tv-user', preparationProtocol: 1});
    await set(ref(c.database(), 'displayAccess/tv-user'), {ownerId: 'owner', deviceId: 'tv', pairingCode: '123456'});
  });
  await assertSucceeds(set(ref(owner, `${path}/request`), request));
  await assertSucceeds(get(ref(tv, `${path}/request`)));
  await assertFails(get(ref(foreign, `${path}/request`)));
  await assertFails(set(ref(tv, `${path}/request`), request));
  await assertSucceeds(set(ref(tv, `${path}/responses/tv`), ready));
  await assertSucceeds(get(ref(owner, `${path}/responses`)));
  await assertFails(set(ref(owner, `${path}/responses/tv`), ready)); // controller cannot forge TV readiness
  await assertFails(set(ref(foreign, `${path}/responses/tv`), ready));
  await assertFails(set(ref(tv, `${path}/responses/other`), ready));
  for (const bad of [{sessionId: 'prepare-obsolete'}, {revision: 2}, {manifestHash: 'b'.repeat(64)},
      {imageCount: 0}, {audioReady: false}, {checkedAtMs: Date.now() - 60000}, {secret: 'extra'}]) {
    await assertFails(set(ref(tv, `${path}/responses/tv`), {...ready, ...bad}));
  }
  await assertSucceeds(set(ref(tv, `${path}/responses/tv`), {...ready, status: 'failed', imageCount: 0, audioReady: false}));
  await assertSucceeds(set(ref(owner, `${path}/request`), {...request, sessionId: 'prepare-session-2', revision: 2}));
  await assertFails(set(ref(tv, `${path}/responses/tv`), ready));
  await assertSucceeds(update(ref(owner, path), {request: {...request, sessionId: 'prepare-session-3', revision: 3}, responses: null}));
  assert.equal((await get(ref(owner, `${path}/responses`))).exists(), false);
  await assertFails(set(ref(owner, `${path}/request`), {...request, targets: {unpaired: true}}));
  await assertFails(set(ref(owner, `${path}/request`), {...request, expiresAtMs: Date.now() - 1}));
  await env.withSecurityRulesDisabled(c => update(ref(c.database(), 'users/owner'), {
    activeSession: {id: 'running', status: 'paused'},
  }));
  await assertFails(set(ref(owner, `${path}/request`), request));
  let active;
  await env.withSecurityRulesDisabled(async c => { active = (await get(ref(c.database(), 'users/owner/activeSession'))).val(); });
  assert.equal(active.id, 'running'); assert.equal(active.status, 'paused');
  await env.withSecurityRulesDisabled(c => update(ref(c.database(), 'users/owner/devices/tv'), {paired: false}));
  await assertFails(get(ref(tv, `${path}/request`)));
  await assertFails(set(ref(tv, `${path}/responses/tv`), ready));
  // STA-170: an existing mapped TV could heartbeat while a missing reverse UID
  // denied both preparation subscription and ACK. Synthetic identifiers only.
  await env.clearDatabase();
  const devicePath = 'users/owner/devices/tv';
  const paired = {id: 'tv', mode: 'display', paired: true, pairingCode: '123456',
    online: true, lastSeenAtMs: Date.now(), playbackProtocol: 5,
    preparationProtocol: 1, displayState: 'auto', name: 'Existing TV'};
  await env.withSecurityRulesDisabled(async c => {
    await set(ref(c.database(), devicePath), paired);
    await set(ref(c.database(), 'displayAccess/tv-user'),
      {ownerId: 'owner', deviceId: 'tv', pairingCode: '123456'});
    await set(ref(c.database(), 'legacyPilotAccess/owner'), {validUntilMs: Date.now() + 600000});
    await set(ref(c.database(), 'subscriptionAccess/owner'), {plan: 'premium', validUntilMs: Date.now() + 600000});
  });
  const recoveryRequest = {...request, expiresAtMs: Date.now() + 60000};
  await assertSucceeds(update(ref(tv, devicePath), {online: true, lastSeenAtMs: Date.now()}));
  await assertSucceeds(set(ref(owner, `${path}/request`), recoveryRequest));
  await assertFails(get(ref(tv, `${path}/request`)));
  await assertFails(set(ref(tv, `${path}/responses/tv`), {...ready, checkedAtMs: Date.now()}));
  // Remove the legacy broad-write allowance: only the new UID field rule can
  // authorize repair. It never grants write access to any sibling field.
  await env.withSecurityRulesDisabled(c => set(ref(c.database(), 'legacyPilotAccess/owner'), null));
  await assertFails(set(ref(owner, `${path}/request`), {...recoveryRequest, revision: 2}));
  await assertFails(update(ref(tv, devicePath), {displayUid: 'tv-user', name: 'unrelated edit'}));
  await assertFails(set(ref(owner, `${devicePath}/displayUid`), 'tv-user'));
  await assertFails(set(ref(foreign, `${devicePath}/displayUid`), 'foreign'));
  const nonAnonymous = env.authenticatedContext('tv-user', {firebase: {sign_in_provider: 'password'}}).database();
  await assertFails(set(ref(nonAnonymous, `${devicePath}/displayUid`), 'tv-user'));
  const beforeRepair = (await get(ref(owner, devicePath))).val();
  const repaired = await assertSucceeds(runTransaction(ref(tv, `${devicePath}/displayUid`),
    current => current === null || current === 'tv-user' ? 'tv-user' : undefined,
    {applyLocally: false}));
  assert.equal(repaired.committed, true);
  assert.deepEqual((await get(ref(owner, devicePath))).val(), {...beforeRepair, displayUid: 'tv-user'});
  await assertSucceeds(runTransaction(ref(tv, `${devicePath}/displayUid`), current => current,
    {applyLocally: false})); // relaunch/retry is idempotent
  await assertSucceeds(get(ref(tv, `${path}/request`)));
  await assertSucceeds(set(ref(tv, `${path}/responses/tv`), {...ready, checkedAtMs: Date.now()}));
  // Another valid TV is excluded using the existing target selection. Its old
  // ready response cannot satisfy or write the new candidate.
  const excluded = env.authenticatedContext('excluded-auth', {firebase: {sign_in_provider: 'anonymous'}}).database();
  await env.withSecurityRulesDisabled(async c => {
    await set(ref(c.database(), 'users/owner/devices/excluded'),
      {...paired, id: 'excluded', displayUid: 'excluded-auth'});
    await set(ref(c.database(), 'displayAccess/excluded-auth'),
      {ownerId: 'owner', deviceId: 'excluded', pairingCode: '123456'});
  });
  const selectedRequest = {...recoveryRequest, sessionId: 'prepare-selected-1', revision: 4};
  await assertSucceeds(update(ref(owner, path), {request: selectedRequest, responses: null}));
  const selectedReady = {...ready, sessionId: selectedRequest.sessionId, revision: 4, checkedAtMs: Date.now()};
  await assertFails(set(ref(excluded, `${path}/responses/excluded`), selectedReady));
  await assertFails(set(ref(tv, `${path}/responses/tv`), {...ready, checkedAtMs: Date.now()}));
  await assertSucceeds(set(ref(tv, `${path}/responses/tv`), selectedReady));
  await assertSucceeds(update(ref(owner, 'users/owner'), {
    'playbackSnapshots/started': {id: 'w', ownerId: 'owner', name: 'Fixture', createdAt: 1, updatedAt: 1},
    activeSession: {schemaVersion: 2, id: 'started', snapshotId: 'started', ownerId: 'owner',
      zoneId: 'main', status: 'playing', stepIndex: 0, remainingMs: 30000,
      anchorServerMs: Date.now(), revision: 1, updatedByDeviceId: 'controller', targetDeviceIds: ['tv']},
  }));
  assert.deepEqual((await get(ref(tv, 'users/owner/activeSession/targetDeviceIds'))).val(), ['tv']);
  assert.equal((await get(ref(excluded, 'users/owner/activeSession/targetDeviceIds'))).val().includes('excluded'), false);

  for (const broken of ['wrong-code', 'missing-code', 'invalid-code', 'wrong-device', 'wrong-owner', 'revoked', 'other-uid', 'unpaired', 'deleting', 'deleting-display']) {
    await env.withSecurityRulesDisabled(async c => {
      await set(ref(c.database(), devicePath), {...paired, ...(broken === 'other-uid' ? {displayUid: 'new-auth'} : {}),
        ...(broken === 'invalid-code' ? {pairingCode: 'invalid'} : {}),
        ...(broken === 'unpaired' ? {paired: false} : {})});
      await set(ref(c.database(), 'displayAccess/tv-user'), broken === 'revoked' ? null :
        {ownerId: broken === 'wrong-owner' ? 'another-owner' : 'owner', deviceId: broken === 'wrong-device' ? 'another-tv' : 'tv',
          ...(broken === 'missing-code' ? {} : {pairingCode: broken === 'wrong-code' ? '654321' : broken === 'invalid-code' ? 'invalid' : '123456'})});
      await set(ref(c.database(), 'accountDeletions/owner'), broken === 'deleting' ? true : null);
      await set(ref(c.database(), 'accountDeletions/tv-user'), broken === 'deleting-display' ? true : null);
    });
    await assertFails(set(ref(tv, `${devicePath}/displayUid`), 'tv-user'));
  }
  console.log('PASS: STA-170 missing UID denies readiness before repair; UID-only mapped recovery, retry, exclusion/start and forged/revoked repair rejection');
  console.log('PASS: preparation ownership, exact candidate/revision, media readiness, stale ACK, unpair and active-class isolation');
} finally { await env.cleanup(); }
