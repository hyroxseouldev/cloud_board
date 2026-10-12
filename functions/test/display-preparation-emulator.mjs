import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {ref, set, get, update} from 'firebase/database';
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
  console.log('PASS: preparation ownership, exact candidate/revision, media readiness, stale ACK, unpair and active-class isolation');
} finally { await env.cleanup(); }
