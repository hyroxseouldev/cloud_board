import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {ref, set, get, query, orderByChild, startAt, endBefore} from 'firebase/database';
assert.match(process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
const [host, port] = process.env.FIREBASE_DATABASE_EMULATOR_HOST.split(':');
const env = await initializeTestEnvironment({projectId: 'demo-cloudboard-operations', database: {
  host, port: Number(port), rules: fs.readFileSync('database.rules.json', 'utf8'),
}});
try {
  await env.withSecurityRulesDisabled(async context => {
    await set(ref(context.database()), {
      displayAccess: {'display-user': {ownerId: 'center', deviceId: 'tv-a'}},
      users: {center: {operations: {events: Object.fromEntries(Array.from({length: 1501}, (_, i) =>
        [`event-${i}`, {id: `event-${i}`, type: 'playback_started', occurredAtMs: 1000 + i, sessionId: `session-${i}`}]))}}},
    });
  });
  const owner = env.authenticatedContext('center').database();
  const foreign = env.authenticatedContext('another-center').database();
  const display = env.authenticatedContext('display-user').database();
  const events = 'users/center/operations/events';
  const result = await assertSucceeds(get(query(ref(owner, events), orderByChild('occurredAtMs'), startAt(1000), endBefore(5000))));
  assert.equal(result.size, 1501);
  await assertFails(get(ref(foreign, events)));
  await assertFails(get(ref(env.unauthenticatedContext().database(), events)));
  for (const type of ['device_online', 'device_offline', 'device_shutdown', 'playback_interrupted', 'playback_restored', 'connection_failed', 'connection_recovered']) {
    const event = {id: type, type, deviceId: 'tv-a', sessionId: 'session', occurredAtMs: 6000, schemaVersion: 2};
    await assertSucceeds(set(ref(display, `${events}/${type}`), event));
    await assertFails(set(ref(display, `${events}/${type}-other-tv`), {...event, deviceId: 'tv-b'}));
    await assertFails(set(ref(foreign, `${events}/${type}-foreign`), event));
  }
  await assertFails(set(ref(display, `${events}/fake-class`), {type: 'playback_started', deviceId: 'tv-a', occurredAtMs: 7000}));
  console.log('PASS operations history: full indexed range, owned TV lifecycle events, cross-center/other-device/anonymous denial');
} finally {
  await env.cleanup();
}
