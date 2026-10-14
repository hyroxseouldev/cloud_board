import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {ref, set, get, query, orderByChild, startAt, endBefore} from 'firebase/database';
import {emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';
const projectId = requireDemo(process.env.GCLOUD_PROJECT);
const env = await initializeTestEnvironment({projectId, database: {
  ...emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST),
  rules: fs.readFileSync(new URL('../../database.rules.json', import.meta.url), 'utf8'),
}});
const registeredDisplay = {id: 'tv-a', mode: 'display', paired: true,
  displayUid: 'display-user', pairingCode: '123456', online: true, lastSeenAtMs: Date.now()};
const lifecycleTypes = ['device_online', 'device_offline', 'device_shutdown',
  'playback_interrupted', 'playback_restored', 'connection_failed', 'connection_recovered'];
try {
  await env.withSecurityRulesDisabled(async context => {
    await set(ref(context.database()), {
      displayAccess: {'display-user': {ownerId: 'center', deviceId: 'tv-a', pairingCode: '123456'}},
      users: {center: {devices: {'tv-a': registeredDisplay}, operations: {events: Object.fromEntries(Array.from({length: 1501}, (_, i) =>
        [`event-${i}`, {id: `event-${i}`, type: 'playback_started', occurredAtMs: 1000 + i, sessionId: `session-${i}`}]))}}},
    });
  });
  const owner = env.authenticatedContext('center').database();
  const foreign = env.authenticatedContext('another-center').database();
  const display = env.authenticatedContext('display-user', {firebase: {sign_in_provider: 'anonymous'}}).database();
  const events = 'users/center/operations/events';
  const result = await assertSucceeds(get(query(ref(owner, events), orderByChild('occurredAtMs'), startAt(1000), endBefore(5000))));
  assert.equal(result.size, 1501);
  await assertFails(get(ref(foreign, events)));
  await assertFails(get(ref(env.unauthenticatedContext().database(), events)));
  await assertSucceeds(get(ref(display, events)));
  for (const type of lifecycleTypes) {
    const event = {id: type, type, deviceId: 'tv-a', sessionId: 'session', occurredAtMs: 6000, schemaVersion: 2};
    await assertSucceeds(set(ref(display, `${events}/${type}`), event));
    await assertFails(set(ref(display, `${events}/${type}-other-tv`), {...event, deviceId: 'tv-b'}));
    await assertFails(set(ref(foreign, `${events}/${type}-foreign`), event));
  }
  await assertFails(set(ref(display, `${events}/fake-class`), {type: 'playback_started', deviceId: 'tv-a', occurredAtMs: 7000}));
  // STA-176 protects every lifecycle type after unpair. A delayed legacy Admin
  // write restoring the raw registration cannot bypass the server tombstone.
  for (const boundary of ['unpaired', 'revoked']) {
    await env.withSecurityRulesDisabled(async context => {
      await set(ref(context.database(), 'users/center/devices/tv-a'),
        {...registeredDisplay, paired: boundary !== 'unpaired'});
      await set(ref(context.database(), 'displayConnectionRevocations/display-user'),
        boundary === 'revoked' ? {'123456': {serverAtMs: Date.now()}} : null);
    });
    await assertFails(get(ref(display, events)));
    for (const type of lifecycleTypes) {
      await assertFails(set(ref(display, `${events}/${boundary}-${type}`),
        {id: `${boundary}-${type}`, type, deviceId: 'tv-a', occurredAtMs: 8000, schemaVersion: 2}));
    }
    await assertSucceeds(get(ref(owner, events)));
  }
  console.log('PASS operations history: full indexed range, registered TV lifecycle events, cross-center/other-device/anonymous denial, unpair/tombstone enforcement for all seven types');
} finally {
  await env.cleanup();
}
