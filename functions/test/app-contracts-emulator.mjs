import assert from 'node:assert/strict';
import {readFileSync, readdirSync} from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, writeBatch, serverTimestamp} from 'firebase/firestore';
import {ref, get, set, update} from 'firebase/database';
import {emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';
const env = await initializeTestEnvironment({projectId: requireDemo(process.env.GCLOUD_PROJECT),
  firestore: {...emulatorAddress(process.env.FIRESTORE_EMULATOR_HOST), rules: readFileSync('firestore.rules', 'utf8')},
  database: {...emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST), rules: readFileSync('database.rules.json', 'utf8')},
});
const directory = 'functions/test/fixtures/app-contracts';
const fixtures = ['build/contracts/app-current.json', ...readdirSync(directory).filter(n => n.endsWith('.json')).map(n => `${directory}/${n}`)];
try {
  for (const file of fixtures) {
    await env.clearFirestore();
    const fixture = JSON.parse(readFileSync(file, 'utf8'), (_, value) => value?.__serverTimestamp ? serverTimestamp() : value);
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
    // No legacyPilotAccess is seeded: these are real paying users, including
    // current controller + old TV (v1) and old controller + current TV.
    for (const plan of ['plus', 'premium']) {
      for (const {state, snapshot, split} of fixture.playback) {
        await env.clearDatabase();
        await env.withSecurityRulesDisabled(c => set(ref(c.database()), {
          subscriptionAccess: {owner: {plan, validUntilMs: Date.now() + 60_000}},
          displayAccess: {tv: {ownerId: 'owner', deviceId: 'tv', pairingCode: '123456'}},
          users: {owner: {devices: {tv: {id: 'tv', mode: 'display', paired: true, displayUid: 'tv', displayState: 'auto', online: true, lastSeenAtMs: 1}}}},
        }));
        const active = ref(owner.database(), 'users/owner/activeSession');
        const changes = {activeSession: state, ...(split ? {[`playbackSnapshots/${state.id}`]: snapshot} : {})};
        await assertSucceeds(update(ref(owner.database(), 'users/owner'), changes));
        const tv = env.authenticatedContext('tv', {firebase: {sign_in_provider: 'anonymous'}}).database();
        assert.equal((await get(ref(tv, 'users/owner/activeSession/id'))).val(), state.id);
        if (split) assert.equal((await get(ref(tv, `users/owner/playbackSnapshots/${state.id}/id`))).val(), snapshot.id);
        else assert.equal((await get(ref(tv, 'users/owner/activeSession/workoutSnapshot/id'))).val(), state.workoutSnapshot.id);
        await assertSucceeds(update(ref(tv, 'users/owner/devices/tv'), {ackRevision: state.revision, sessionId: state.id}));
        for (const uid of ['other', 'unpaired-tv']) {
          const foreign = env.authenticatedContext(uid).database();
          await assertFails(get(ref(foreign, 'users/owner/activeSession')));
          await assertFails(update(ref(foreign, 'users/owner'), changes));
        }
        await assertFails(set(ref(tv, 'users/owner/activeSession'), state));
        await assertFails(set(active, {...state, targetDeviceIds: ['unpaired-tv']}));
        await assertSucceeds(set(active, {...state, status: 'paused', revision: state.revision + 1}));
        // V2 can continue controlling its immutable snapshot after expiry.
        // V1 keeps playing locally; after expiry it may only stop, never start
        // or resume a changed inline snapshot (RTDB cannot compare deep maps).
        await env.withSecurityRulesDisabled(c => set(ref(c.database(), 'subscriptionAccess/owner/validUntilMs'), Date.now() - 1_000));
        const paused = {...state, status: 'paused', revision: state.revision + 2};
        if (split) await assertSucceeds(set(active, paused));
        else await assertFails(set(active, paused));
        await assertFails(set(active, {...paused, id: 'new-expired-session', ...(split ? {snapshotId: 'new-expired-session'} : {})}));
        await assertFails(set(active, {...paused, targetDeviceIds: ['unpaired-tv']}));
        if (!split) await assertFails(set(active, {...paused, workoutSnapshot: {...state.workoutSnapshot, name: 'Expired replacement'}}));
        await assertSucceeds(set(active, {...paused, status: 'completed', revision: paused.revision + 1}));
        await assertFails(set(active, {...paused, status: 'playing', revision: paused.revision + 2}));
        await assertSucceeds(set(active, null));
        await assertFails(set(active, state));
        await env.withSecurityRulesDisabled(c => set(ref(c.database(), 'displayAccess/tv'), null));
        await assertFails(get(ref(tv, 'users/owner/activeSession')));
        await assertFails(update(ref(tv, 'users/owner/devices/tv'), {ackRevision: 99}));
      }
    }
    console.log(`PASS ${file}: supported paid v1/v2, paired TV, expired v2 continuation/v1 stop, immutable v2 class, foreign/removed targets`);
  }
} finally { await env.cleanup(); }
