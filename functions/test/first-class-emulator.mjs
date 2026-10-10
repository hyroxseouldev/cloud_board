import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, getDocs, collection, runTransaction, setDoc, Timestamp} from 'firebase/firestore';
import {ref, get, set, runTransaction as transact, serverTimestamp} from 'firebase/database';

for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_DATABASE_EMULATOR_HOST']) {
  assert.match(process.env[key] || '', /^(127\.0\.0\.1|localhost):\d+$/);
}
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
const [rtHost, rtPort] = process.env.FIREBASE_DATABASE_EMULATOR_HOST.split(':');
const env = await initializeTestEnvironment({projectId: 'demo-cloudboard-first-class',
  firestore: {host, port: Number(port), rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')},
  database: {host: rtHost, port: Number(rtPort), rules: fs.readFileSync(new URL('../../database.rules.json', import.meta.url), 'utf8')},
});
const fixtures = JSON.parse(fs.readFileSync(new URL('../../build/contracts/starter-workouts.json', import.meta.url), 'utf8'),
  (_, v) => v && typeof v === 'object' && Object.hasOwn(v, '__timestampMillis') ? Timestamp.fromMillis(v.__timestampMillis) : v);

// Replay the create-if-absent branch using the app's actual workout + summary
// payloads, against the unchanged deployed rules contract.
function importStarter(db, fixture) {
  return runTransaction(db, async tx => {
    await tx.get(doc(db, 'users/owner/settings/workout'));
    const target = doc(db, `users/owner/workouts/${fixture.workout.id}`);
    const previous = await tx.get(target);
    if (previous.exists()) return previous.data();
    tx.set(target, fixture.workout);
    tx.set(doc(db, `users/owner/workoutSummaries/${fixture.workout.id}`), fixture.summary);
    return fixture.workout;
  });
}
try {
  const owner = env.authenticatedContext('owner').firestore();
  for (const fixture of fixtures) {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'users/owner/settings/workout'), {contentOnly: fixture.contentOnly}));
    await Promise.all([assertSucceeds(importStarter(owner, fixture)), assertSucceeds(importStarter(owner, fixture))]);
    assert.equal((await getDocs(collection(owner, 'users/owner/workouts'))).size, 1);
    const path = `users/owner/workouts/${fixture.workout.id}`;
    await setDoc(doc(owner, path), {...fixture.workout, name: 'My edited class'});
    const retry = await assertSucceeds(importStarter(owner, fixture));
    assert.equal(retry.name, 'My edited class');
    assert.equal((await getDoc(doc(owner, path))).data().name, 'My edited class');
    await assertFails(importStarter(env.authenticatedContext('other').firestore(), fixture));
    await assertFails(importStarter(env.unauthenticatedContext().firestore(), fixture));
  }
  console.log('PASS: 3 starter packs and owned conversions, both schemas, concurrent/retried import preserves edits, cross-owner/guest denied');

  const ownerDb = env.authenticatedContext('owner').database();
  const tvDb = env.authenticatedContext('tv-user', {firebase: {sign_in_provider: 'anonymous'}}).database();
  const otherDb = env.authenticatedContext('other').database();
  const path = 'users/owner/devices/tv';
  await env.withSecurityRulesDisabled(async c => {
    const db = c.database();
    await set(ref(db), {
      subscriptionAccess: {owner: {managed: true, plan: 'plus', validUntilMs: Date.now() + 60000}},
      displayAccess: {'tv-user': {ownerId: 'owner', deviceId: 'tv', pairingCode: '123456'}},
      users: {owner: {devices: {
        tv: {id: 'tv', mode: 'display', displayUid: 'tv-user', online: true, lastSeenAtMs: 1, paired: true, displayState: 'auto'},
        otherTv: {id: 'otherTv', mode: 'display', displayUid: 'other-tv', online: true, lastSeenAtMs: 1, paired: true, displayState: 'auto'},
      }}},
    });
  });
  const identify = db => transact(ref(db, path), value => value == null ? null : ({...value,
    identificationId: 'new-attempt', identificationExpiresAtMs: Date.now() + 30000, identificationAck: null}), {applyLocally: false});
  await assertSucceeds(identify(ownerDb));
  assert.equal((await get(ref(ownerDb, `${path}/identificationAck`))).exists(), false);
  await assertSucceeds(transact(ref(tvDb, path), value => value == null ? null : ({...value,
    identificationAck: 'new-attempt', online: true, lastSeenAtMs: serverTimestamp()}), {applyLocally: false}));
  assert.equal((await get(ref(ownerDb, `${path}/identificationAck`))).val(), 'new-attempt');
  await assertFails(set(ref(otherDb, `${path}/identificationId`), 'attack'));
  await assertFails(set(ref(tvDb, 'users/owner/devices/otherTv/identificationAck'), 'attack'));
  const event = {id: 'first-class-test', type: 'onboarding_workout_completed', sessionId: 's', centerId: 'c', occurredAtMs: 1, scheduled: false};
  await assertSucceeds(set(ref(ownerDb, 'users/owner/operations/events/first-class-test'), event));
  await assertFails(set(ref(tvDb, 'users/owner/operations/events/forged'), {...event, deviceId: 'tv'}));
  await set(ref(ownerDb, path), null);
  await assertSucceeds(identify(ownerDb));
  assert.equal((await get(ref(ownerDb, path))).exists(), false);
  console.log('PASS: silent TV request/ACK with unchanged Plus rules, cross-device writes denied, removed TV not recreated');
} finally {
  await env.cleanup();
}
