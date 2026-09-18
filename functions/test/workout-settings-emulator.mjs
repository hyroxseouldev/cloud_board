import {execFileSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp} from 'firebase/firestore';
import {normalizeSettings} from '../src/workout-settings-migration.js';
assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
const env = await initializeTestEnvironment({projectId: 'demo-cloudboard-settings', firestore: {
  host, port: Number(port), rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
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
  await assertFails(updateDoc(profile, {workoutSettings: {...preferences, brandL: 'old writer'}}));
  await assertFails(deleteDoc(settings));
  await assertSucceeds(updateDoc(profile, {displayName: 'Profile unchanged by settings'}));
  const update = writeBatch(owner);
  const changed = {...preferences, brandL: 'New'};
  update.set(settings, {...data(2), preferences: changed});
  update.update(profile, {workoutSettings: changed});
  await assertSucceeds(update.commit());
  const workout = {id: 'w', ownerId: 'owner', author: {id: 'owner'}, name: 'Workout', folder: '', modules: [],
    createdAt: Timestamp.fromMillis(10), updatedAt: Timestamp.fromMillis(10)};
  await assertSucceeds(setDoc(doc(owner, 'users/owner/workouts/w'), {...workout, brandL: 'Legacy'}));
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(), 'users/owner/settings/workout'), {contentOnly: true});
  });
  await assertFails(setDoc(doc(owner, 'users/owner/workouts/w'), {...workout, brandL: 'Legacy'}));
  await assertSucceeds(setDoc(doc(owner, 'users/owner/workouts/w'), {...workout, schemaVersion: 2}));
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'accountDeletions/owner'), {status: 'pending'});
  });
  await assertFails(getDoc(settings));
  console.log('PASS: ownership, settings revision, legacy-writer protection, content-only activation, deletion lock');
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
    console.log('PASS: dry-run, backup, prepare, mixed-account skip, finalize and idempotent retry (demo only)');
  } finally { fs.rmSync(backup, {recursive: true, force: true}); }
} finally { await env.cleanup(); }
