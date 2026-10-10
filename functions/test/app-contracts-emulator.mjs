import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, writeBatch, serverTimestamp} from 'firebase/firestore';
import {ref, get, set, update} from 'firebase/database';
import {emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';
const env = await initializeTestEnvironment({projectId: requireDemo(process.env.GCLOUD_PROJECT),
  firestore: {...emulatorAddress(process.env.FIRESTORE_EMULATOR_HOST), rules: readFileSync('firestore.rules', 'utf8')},
  database: {...emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST), rules: readFileSync('database.rules.json', 'utf8')},
});
const fixture = JSON.parse(readFileSync('build/contracts/app-current.json', 'utf8'), (_, value) => value?.__serverTimestamp ? serverTimestamp() : value);
try {
  const owner = env.authenticatedContext('owner', {firebase: {sign_in_provider: 'password'}}), db = owner.firestore();
  const settings = doc(db, 'users/owner/settings/workout');
  const create = writeBatch(db);
  create.set(settings, fixture.settings);
  create.set(doc(db, 'users/owner'), {uid: 'owner', workoutSettings: fixture.settings.preferences});
  await assertSucceeds(create.commit());
  assert.equal((await getDoc(settings)).data().revision, 1);
  await assertFails(setDoc(settings, fixture.settings));
  await assertFails(setDoc(settings, {...fixture.settings, revision: 2, contentOnly: true}));
  for (const context of [env.authenticatedContext('other'), env.unauthenticatedContext()]) {
    await assertFails(getDoc(doc(context.firestore(), 'users/owner/settings/workout')));
  }
  await env.withSecurityRulesDisabled(c => set(ref(c.database()), {
    subscriptionAccess: {owner: {plan: 'plus', validUntilMs: Date.now() + 60_000}},
    legacyPilotAccess: {owner: {validUntilMs: Date.now() + 60_000}},
    displayAccess: {tv: {ownerId: 'owner', deviceId: 'tv', pairingCode: '123456'}},
    users: {owner: {devices: {tv: {id: 'tv', mode: 'display', paired: true, displayUid: 'tv', displayState: 'auto', online: true, lastSeenAtMs: 1}}}},
  }));
  const tv = env.authenticatedContext('tv', {firebase: {sign_in_provider: 'anonymous'}}).database();
  for (const {state, snapshot, split} of fixture.playback) {
    const changes = {activeSession: state, ...(split ? {[`playbackSnapshots/${state.id}`]: snapshot} : {})};
    await assertSucceeds(update(ref(owner.database(), 'users/owner'), changes));
    assert.equal((await get(ref(tv, 'users/owner/activeSession/id'))).val(), state.id);
    await assertSucceeds(update(ref(tv, 'users/owner/devices/tv'), {ackRevision: state.revision, sessionId: state.id}));
    for (const uid of ['other', 'unpaired-tv']) {
      const foreign = env.authenticatedContext(uid).database();
      await assertFails(get(ref(foreign, 'users/owner/activeSession')));
      await assertFails(update(ref(foreign, 'users/owner'), changes));
    }
    await assertFails(set(ref(tv, 'users/owner/activeSession'), state));
  }
  // A paid client must use v2; pilot fallback is not silently granted to everyone.
  await env.withSecurityRulesDisabled(c => set(ref(c.database(), 'legacyPilotAccess/owner'), null));
  await assertFails(set(ref(owner.database(), 'users/owner/activeSession'), fixture.playback[0].state));
  await env.withSecurityRulesDisabled(c => set(ref(c.database(), 'displayAccess/tv'), null));
  await assertFails(get(ref(tv, 'users/owner/activeSession')));
  await assertFails(update(ref(tv, 'users/owner/devices/tv'), {ackRevision: 99}));
  console.log('PASS actual Flutter settings and v1/v2 playback: owner, legacy pilot, paired/removed TV and foreign account');
} finally { await env.cleanup(); }
