import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, setDoc} from 'firebase/firestore';
import {ref, set, update, get} from 'firebase/database';
import {emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';
import {freeValidUntilMs, resolveGrants, freeGrant} from '../src/billing-policy.js';

const env = await initializeTestEnvironment({
  projectId: requireDemo(process.env.GCLOUD_PROJECT),
  firestore: {...emulatorAddress(process.env.FIRESTORE_EMULATOR_HOST), rules: readFileSync('firestore.rules', 'utf8')},
  database: {...emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST), rules: readFileSync('database.rules.json', 'utf8')},
});
const owner = env.authenticatedContext('owner', {firebase: {sign_in_provider: 'password'}});
const access = {...resolveGrants([freeGrant({enabled: true})]), revision: 1};
const state = id => ({id, ownerId: 'owner', zoneId: 'main', status: 'playing', stepIndex: 0,
  remainingMs: 60000, anchorServerMs: Date.now(), revision: 1, updatedByDeviceId: 'phone',
  workoutSnapshot: {id: 'workout', name: 'Saved class'}, targetDeviceIds: ['tv']});

try {
  await env.clearFirestore();
  await env.clearDatabase();
  // A legacy client may retain arbitrary profile fields. None is proof of SMS
  // verification, and it cannot write any of the actual activation records.
  await assertSucceeds(setDoc(doc(owner.firestore(), 'users/owner'), {uid: 'owner', phoneVerified: true}));
  for (const [path, value] of [
    ['users/owner/onboarding/progress', {phoneVerified: true, storeId: 'forged'}],
    ['onboardingFree/owner', {enabled: true}],
    ['onboardingPhoneChallenges/owner', {verified: true}],
    ['subscriptionEntitlements/owner', access],
  ]) await assertFails(setDoc(doc(owner.firestore(), path), value));
  await assertFails(set(ref(owner.database(), 'subscriptionAccess/owner'), access));
  await assertFails(set(ref(owner.database(), 'legacyPilotAccess/owner'), {validUntilMs: freeValidUntilMs}));
  // Keep a previously paired TV to test the stronger case: pairing alone must
  // not let an unverified account start a class.
  await env.withSecurityRulesDisabled(async admin => {
    await set(ref(admin.database(), 'users/owner/devices/tv'), {id: 'tv', mode: 'display',
      paired: true, displayUid: 'tv-auth', displayState: 'auto', online: true, lastSeenAtMs: Date.now()});
    await set(ref(admin.database(), 'displayAccess/tv-auth'), {ownerId: 'owner', deviceId: 'tv'});
  });
  const session = ref(owner.database(), 'users/owner/activeSession');
  await assertFails(set(session, state('unverified')));

  // Only the server's verified projection enables the same installed-client
  // wire contract; no new trial or far-future expiry is exposed as a trial.
  await env.withSecurityRulesDisabled(async admin => {
    await setDoc(doc(admin.firestore(), 'users/owner/onboarding/progress'), {phoneVerified: true});
    await setDoc(doc(admin.firestore(), 'subscriptionEntitlements/owner'), access);
    await set(ref(admin.database(), 'subscriptionAccess/owner'), access);
  });
  await assertSucceeds(set(session, state('verified')));
  const tv = env.authenticatedContext('tv-auth', {firebase: {sign_in_provider: 'anonymous'}}).database();
  assert.equal((await get(ref(tv, 'users/owner/activeSession/id'))).val(), 'verified');
  await assertSucceeds(update(ref(tv, 'users/owner/devices/tv'), {ackRevision: 1, sessionId: 'verified'}));
  await assertFails(set(ref(owner.database(), 'subscriptionAccess/owner/webGrant/phoneVerified'), true));
  console.log('PASS verified Free: client proof forgery denied, unverified TV denied, server activation reaches paired TV');
} finally {
  await env.cleanup();
}
