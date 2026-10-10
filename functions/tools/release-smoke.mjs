import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {initializeApp as adminApp, applicationDefault, deleteApp as deleteAdmin} from 'firebase-admin/app';
import {getDatabase as adminDatabase} from 'firebase-admin/database';
import {initializeApp, deleteApp} from 'firebase/app';
import {getAuth, connectAuthEmulator, signInWithCustomToken, signOut} from 'firebase/auth';
import {getFirestore, connectFirestoreEmulator, doc, getDocFromServer, runTransaction, Timestamp, terminate} from 'firebase/firestore';
import {getDatabase, connectDatabaseEmulator, ref, update, goOffline} from 'firebase/database';
import {getStorage, connectStorageEmulator, ref as storageRef, uploadBytes, getBytes, deleteObject} from 'firebase/storage';
import {canaryUsers, checkRunId, prepareCanary, cleanupCanary} from './release-canary.mjs';
import {targets} from '../../tool/firebase/release.mjs';
import {readJson, writeJson, emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';

export function preflight(env = process.env) {
  assert.equal(env.FIREBASE_RELEASE_CANARY_ENABLED, 'true', 'Enable the provisioned release canary before promoting main');
  assert.match(env.FIREBASE_WEB_API_KEY || '', /^AIza[A-Za-z0-9_-]+$/, 'Firebase web API key required');
  assert.equal(env.GITHUB_REF, 'refs/heads/main', 'Live smoke only runs on main');
  for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_DATABASE_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST']) assert(!env[key], 'Emulator environment in production job');
}
const decode = data => JSON.parse(JSON.stringify(data), (_, value) => value?.__timestampMillis !== undefined ? Timestamp.fromMillis(value.__timestampMillis) : value);
const deny = task => assert.rejects(task, error => ['permission-denied', 'PERMISSION_DENIED', 'storage/unauthorized'].includes(error.code), 'Expected a permission denial, not a network/server error');

export async function runSmoke({app, config, runId, emulator = false}) {
  const id = checkRunId(runId);
  if (emulator) requireDemo(config.projectId);
  else {
    assert.equal(config.projectId, targets.project); assert.equal(config.databaseURL, targets.databaseURL); assert.equal(config.storageBucket, targets.storage);
  }
  const result = {format: 1, runId, status: 'running', phase: 'setup', cleanup: 'pending', checks: [], startedAt: new Date().toISOString()};
  const clients = [];
  try {
    const tokens = await prepareCanary(app, runId);
    for (const role of ['owner', 'other', 'tv']) {
      const client = initializeApp(config, `release-${role}-${runId}`); clients.push(client);
      const auth = getAuth(client), firestore = getFirestore(client), database = getDatabase(client), storage = getStorage(client);
      if (emulator) {
        const fs = emulatorAddress(process.env.FIRESTORE_EMULATOR_HOST), rt = emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST), st = emulatorAddress(process.env.FIREBASE_STORAGE_EMULATOR_HOST);
        connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, {disableWarnings: true});
        connectFirestoreEmulator(firestore, fs.host, fs.port); connectDatabaseEmulator(database, rt.host, rt.port); connectStorageEmulator(storage, st.host, st.port);
      }
      assert.equal((await signInWithCustomToken(auth, tokens[role])).user.uid, canaryUsers[role]);
    }
    const [ownerApp, otherApp, tvApp] = clients;
    result.phase = 'workout';
    const owner = canaryUsers.owner, db = getFirestore(ownerApp);
    const fixture = decode(readJson('build/contracts/workout-save-current.json').scenarios.find(s => s.contentOnly).writes[0]);
    const workout = {...fixture.workout, id, ownerId: owner, author: {...fixture.workout.author, id: owner}};
    const summary = {...fixture.summary, id};
    const workoutRef = doc(db, `users/${owner}/workouts/${id}`), summaryRef = doc(db, `users/${owner}/workoutSummaries/${id}`);
    const save = name => runTransaction(db, async tx => {
      await tx.get(doc(db, `users/${owner}/settings/workout`)); await tx.get(workoutRef);
      tx.set(workoutRef, {...workout, name}); tx.set(summaryRef, {...summary, name});
    });
    await save('Release check'); await save('Release check updated');
    assert.equal((await getDocFromServer(workoutRef)).data().name, 'Release check updated');
    assert.equal((await getDocFromServer(summaryRef)).data().name, 'Release check updated');
    result.checks.push('workout');
    result.phase = 'storage';
    const storage = getStorage(ownerApp), path = `users/${owner}/workouts/${id}/probe.png`, image = storageRef(storage, path);
    await uploadBytes(image, new Uint8Array([137,80,78,71,13,10,26,10]), {contentType: 'image/png'});
    assert.equal((await getBytes(image)).byteLength, 8);
    await deny(getBytes(storageRef(getStorage(otherApp), path)));
    await deleteObject(image); result.checks.push('storage');
    result.phase = 'tv';
    const wire = readJson('build/contracts/app-current.json').playback.find(p => p.split);
    const state = {...wire.state, id, ownerId: owner, snapshotId: id, workoutId: id, targetDeviceIds: [id]};
    const snapshot = {...wire.snapshot, id, ownerId: owner, author: {...wire.snapshot.author, id: owner}};
    await update(ref(getDatabase(ownerApp), `users/${owner}`), {activeSession: state, [`playbackSnapshots/${id}`]: snapshot});
    const readRealtime = async (client, path) => {
      const base = emulator ? `http://${process.env.FIREBASE_DATABASE_EMULATOR_HOST}` : config.databaseURL;
      const url = new URL(`${base}/${path}.json`);
      if (emulator) url.searchParams.set('ns', new URL(config.databaseURL).hostname.split('.')[0]);
      url.searchParams.set('auth', await getAuth(client).currentUser.getIdToken());
      const response = await fetch(url, {signal: AbortSignal.timeout(20_000)});
      if (!response.ok) { const e = new Error(`Realtime read failed (${response.status})`); e.code = response.status === 401 || response.status === 403 ? 'permission-denied' : 'unavailable'; throw e; }
      return response.json();
    };
    assert.equal((await readRealtime(tvApp, `users/${owner}/activeSession`)).id, id);
    assert.equal((await readRealtime(tvApp, `users/${owner}/playbackSnapshots/${id}`)).id, id);
    await update(ref(getDatabase(tvApp), `users/${owner}/devices/${id}`), {ackRevision: state.revision, sessionId: id});
    assert.equal((await readRealtime(ownerApp, `users/${owner}/devices/${id}`)).ackRevision, state.revision);
    result.checks.push('tv');
    result.phase = 'isolation';
    await deny(getDocFromServer(doc(getFirestore(otherApp), `users/${owner}/workouts/${id}`)));
    await deny(runTransaction(getFirestore(otherApp), async tx => tx.set(doc(getFirestore(otherApp), `users/${owner}/workouts/${id}`), {...workout, name: 'must not persist'})));
    await deny(readRealtime(otherApp, `users/${owner}/activeSession`));
    await deny(update(ref(getDatabase(tvApp), `users/${owner}/activeSession`), {status: 'completed'}));
    // Remove only our synthetic pairing to verify the formerly paired TV loses
    // access too. Admin is used for fixture setup/cleanup, never the assertion.
    await adminDatabase(app).ref(`displayAccess/${canaryUsers.tv}`).remove();
    await deny(readRealtime(tvApp, `users/${owner}/activeSession`));
    await deny(readRealtime(tvApp, `users/${owner}/playbackSnapshots/${id}`));
    result.checks.push('isolation'); result.status = 'success';
  } catch (error) {
    result.status = 'failure'; result.error = error.name === 'AssertionError' ? 'Contract assertion failed' : String(error.code || 'operation-failed');
  } finally {
    try { await cleanupCanary(app, runId); result.cleanup = 'success'; }
    catch { result.cleanup = 'failure'; result.status = 'failure'; }
    const closed = await Promise.allSettled(clients.map(async client => {
      goOffline(getDatabase(client));
      await signOut(getAuth(client));
      await terminate(getFirestore(client));
      await deleteApp(client);
    }));
    if (closed.some(r => r.status === 'rejected')) { result.status = 'failure'; result.cleanup = 'failure'; }
    result.finishedAt = new Date().toISOString();
  }
  return result;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  preflight();
  if (process.argv[2] !== 'preflight') {
    const app = adminApp({credential: applicationDefault(), projectId: targets.project, databaseURL: targets.databaseURL, storageBucket: targets.storage});
    try {
      const result = await runSmoke({app, config: {projectId: targets.project, databaseURL: targets.databaseURL, storageBucket: targets.storage, apiKey: process.env.FIREBASE_WEB_API_KEY}, runId: `${process.env.GITHUB_RUN_ID}-${process.env.GITHUB_RUN_ATTEMPT}`});
      writeJson('build/release/smoke.json', result);
      console.log(`Release smoke: ${result.status}; cleanup: ${result.cleanup}`);
      if (result.status !== 'success') process.exitCode = 1;
    } finally { await deleteAdmin(app); }
  }
}
