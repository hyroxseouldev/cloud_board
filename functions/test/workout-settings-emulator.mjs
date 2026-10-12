import {execFileSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp} from 'firebase/firestore';
import {normalizeSettings} from '../src/workout-settings-migration.js';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {syncLegacyWorkoutSettings} from '../src/workout-settings-compatibility.js';
assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
const env = await initializeTestEnvironment({projectId: 'demo-cloudboard-settings', firestore: {
  host, port: Number(port), rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
const admin = initializeApp({projectId: 'demo-cloudboard-settings'});
const adminDb = getFirestore(admin);
try {
  await env.clearFirestore();
  const owner = env.authenticatedContext('owner').firestore();
  const other = env.authenticatedContext('other').firestore();
  const profile = doc(owner, 'users/owner');
  const settings = doc(owner, 'users/owner/settings/workout');
  const preferences = normalizeSettings({});
  const data = revision => ({schemaVersion: 1, revision, updatedAt: serverTimestamp(), contentOnly: false, preferences});
  await assertSucceeds(setDoc(profile, {uid: 'owner'}));
  const batch = writeBatch(owner);
  batch.set(settings, data(1));
  batch.set(profile, {workoutSettings: preferences}, {merge: true});
  await assertSucceeds(batch.commit());
  await assertFails(getDoc(doc(other, 'users/owner/settings/workout')));
  await assertFails(setDoc(settings, data(1))); // stale revision
  await assertFails(setDoc(settings, {...data(2), contentOnly: true})); // admin only
  await assertFails(setDoc(settings, {...data(2), preferences: {...preferences, soundVolume: 2}}));
  const beforeLegacy = (await getDoc(profile)).data();
  const legacyValue = {...preferences, brandL: 'old writer'};
  await assertSucceeds(updateDoc(profile, {workoutSettings: legacyValue}));
  const legacyEvent = await adminDb.doc('users/owner').get();
  await assertSucceeds(updateDoc(profile, {displayName: 'An unrelated later edit'}));
  assert.equal(await syncLegacyWorkoutSettings(adminDb, 'owner', beforeLegacy, legacyEvent.data(), legacyEvent.updateTime), true);
  assert.equal((await getDoc(settings)).data().preferences.brandL, 'old writer');
  assert.equal((await getDoc(settings)).data().revision, 2);
  assert.equal(await syncLegacyWorkoutSettings(adminDb, 'owner', beforeLegacy, legacyEvent.data(), legacyEvent.updateTime), false);
  await assertFails(updateDoc(profile, {workoutSettings: {...preferences, soundVolume: 5}}));
  await assertFails(updateDoc(profile, {subscriptionPlan: 'premium'}));
  await assertFails(deleteDoc(settings));
  await assertSucceeds(updateDoc(profile, {displayName: 'Profile unchanged by settings'}));
  const update = writeBatch(owner);
  const changed = {...preferences, brandL: 'New'};
  update.set(settings, {...data(3), preferences: changed});
  update.update(profile, {workoutSettings: changed});
  await assertSucceeds(update.commit());
  assert.equal(await syncLegacyWorkoutSettings(adminDb, 'owner', beforeLegacy, legacyEvent.data(), legacyEvent.updateTime), false);
  assert.equal((await getDoc(settings)).data().preferences.brandL, 'New');
  // Old countdown-only writers are mirrored without resetting the brand/sound.
  const beforeCountdown = (await getDoc(profile)).data();
  await assertSucceeds(updateDoc(profile, {countdownDefaults: {...preferences.countdown, seconds: 17}}));
  const countdownEvent = await adminDb.doc('users/owner').get();
  assert.equal(await syncLegacyWorkoutSettings(adminDb, 'owner', beforeCountdown, countdownEvent.data(), countdownEvent.updateTime), true);
  assert.equal((await getDoc(settings)).data().preferences.countdown.seconds, 17);
  assert.equal((await getDoc(settings)).data().preferences.brandL, 'New');
  const reflected = await adminDb.doc('users/owner').get();
  assert.equal(await syncLegacyWorkoutSettings(adminDb, 'owner', countdownEvent.data(), reflected.data(), reflected.updateTime), false);
  assert.equal((await getDoc(settings)).data().revision, 4);
  await assertFails(setDoc(doc(owner, 'runtimePolicy/current'), {schemaVersion: 1}));
  await assertSucceeds(getDoc(doc(owner, 'runtimePolicy/current')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'runtimePolicy/current')));
  const workout = {id: 'w', ownerId: 'owner', author: {id: 'owner'}, name: 'Workout', folder: '', modules: [],
    createdAt: Timestamp.fromMillis(10), updatedAt: Timestamp.fromMillis(10)};
  await assertSucceeds(setDoc(doc(owner, 'users/owner/workouts/w'), {...workout, brandL: 'Legacy'}));
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), 'users/owner/settings/workout'), {contentOnly: true});
  });
  await assertSucceeds(setDoc(doc(owner, 'users/owner/workouts/w'), {...workout, brandL: 'Legacy'}));
  await assertSucceeds(setDoc(doc(owner, 'users/owner/workouts/w'), {...workout, schemaVersion: 2}));
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'accountDeletions/owner'), {status: 'pending'});
  });
  await assertFails(getDoc(settings));
  console.log('PASS: ownership, settings revision, installed legacy writers, event ordering/retry, countdown bridge, runtime policy and deletion lock');
  const backup = fs.mkdtempSync(join(tmpdir(), 'cloudboard-settings-test-'));
  const migrate = (uid, ...args) => JSON.parse(execFileSync(process.execPath,
    [new URL('../scripts/migrate-workout-settings.mjs', import.meta.url).pathname,
      '--project', 'demo-cloudboard-settings', '--uid', uid, ...args], {encoding: 'utf8'}));
  try {
    await env.withSecurityRulesDisabled(async context => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/migrate'), {uid: 'migrate', displayName: 'Keep me'});
      await setDoc(doc(db, 'users/migrate/workouts/w'), {...workout, ownerId: 'migrate', author: {id: 'migrate'}, brandL: 'Old', countdownSeconds: 9});
      await setDoc(doc(db, 'users/mixed'), {uid: 'mixed'});
      await setDoc(doc(db, 'users/mixed/workouts/a'), {...workout, brandL: 'A'});
      await setDoc(doc(db, 'users/mixed/workouts/b'), {...workout, brandL: 'B'});
    });
    assert.equal(migrate('migrate').report[0].status, 'uniform-legacy');
    assert.equal(migrate('migrate', '--apply', '--backup-dir', backup).report[0].status, 'prepared');
    assert.equal(migrate('mixed', '--apply', '--backup-dir', backup).report[0].status, 'needs-selection');
    assert.equal(migrate('migrate', '--apply', '--backup-dir', backup, '--finalize', '--confirm-compatible-clients').report[0].status, 'finalized');
    // Retry after cleanup is safe and does not bump an already-finalized revision.
    assert.equal(migrate('migrate', '--apply', '--backup-dir', backup, '--finalize', '--confirm-compatible-clients').report[0].status, 'finalized');
    await env.withSecurityRulesDisabled(async context => {
      const db = context.firestore();
      const canonical = (await getDoc(doc(db, 'users/migrate/settings/workout'))).data();
      const content = (await getDoc(doc(db, 'users/migrate/workouts/w'))).data();
      const profile = (await getDoc(doc(db, 'users/migrate'))).data();
      assert.equal(canonical.contentOnly, true);
      assert.equal(canonical.preferences.countdown.seconds, 9);
      assert.equal(canonical.revision, 2);
      assert.equal(content.schemaVersion, 2);
      assert.equal('brandL' in content, false);
      assert.deepEqual(content.modules, workout.modules);
      assert.equal(content.createdAt.toMillis(), 10);
      assert.equal(profile.displayName, 'Keep me');
      assert.equal('workoutSettings' in profile, false);
      assert.equal((await getDoc(doc(db, 'users/mixed/settings/workout'))).exists(), false);
    });
    assert.equal(migrate('migrate', '--apply', '--backup-dir', backup, '--restore-compatibility').report[0].status, 'compatibility-restored');
    assert.equal(migrate('migrate', '--apply', '--backup-dir', backup, '--restore-compatibility').report[0].status, 'compatibility-restored');
    const restoredSettings = (await adminDb.doc('users/migrate/settings/workout').get()).data();
    const restoredContent = (await adminDb.doc('users/migrate/workouts/w').get()).data();
    assert.equal(restoredSettings.contentOnly, false);
    assert.equal(restoredSettings.revision, 3);
    assert.equal(restoredContent.schemaVersion, undefined);
    assert.equal(restoredContent.brandL, 'Old');
    assert.equal(restoredContent.countdownSeconds, 9);
    assert.equal(restoredContent.createdAt.toMillis(), 10);
    assert.deepEqual(restoredContent.modules, workout.modules);
    const oldApp = env.authenticatedContext('migrate').firestore();
    await assertSucceeds(updateDoc(doc(oldApp, 'users/migrate/workouts/w'), {name: 'Edited on old app'}));
    console.log('PASS: dry-run, backup, prepare, mixed-account skip, demo-only finalize and non-destructive compatibility restore');
  } finally { fs.rmSync(backup, {recursive: true, force: true}); }
} finally { await env.cleanup(); await deleteApp(admin); }
