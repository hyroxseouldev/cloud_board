import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getDatabase} from 'firebase-admin/database';
import {getFirestore} from 'firebase-admin/firestore';
import {runSmoke} from '../tools/release-smoke.mjs';
import {cleanupCanary, prepareCanary, canaryUsers} from '../tools/release-canary.mjs';
import {requireDemo, writeJson} from '../../tool/firebase/common.mjs';
const projectId = requireDemo(process.env.GCLOUD_PROJECT);
const config = {projectId, databaseURL: `https://${projectId}.firebaseio.com`, storageBucket: `${projectId}.firebasestorage.app`, apiKey: 'demo-key'};
const app = initializeApp(config);
try {
  for (const runId of ['123-1', '123-2']) {
    const result = await runSmoke({app, config, runId, emulator: true});
    writeJson(`build/firebase-contracts/smoke-${runId}.json`, result);
    assert.equal(result.status, 'success', JSON.stringify(result));
    assert.equal(result.cleanup, 'success');
    await cleanupCanary(app, runId);
    assert.equal((await getDatabase(app).ref(`users/${canaryUsers.owner}/activeSession`).get()).exists(), false);
    assert.equal((await getFirestore(app).doc(`users/${canaryUsers.owner}/workouts/release-${runId}`).get()).exists, false);
  }
  await prepareCanary(app, '123-3');
  await assert.rejects(prepareCanary(app, '123-4'), /owns the lease/);
  await getDatabase(app).ref('releaseCanaryLease/expiresAtMs').set(0);
  await assert.rejects(prepareCanary(app, '123-4'), /owns the lease/);
  await cleanupCanary(app, '123-4');
  assert.equal((await getDatabase(app).ref('releaseCanaryLease/runId').get()).val(), '123-3');
  await cleanupCanary(app, '123-3');
  await prepareCanary(app, '123-4'); await cleanupCanary(app, '123-4');
  console.log('PASS repeated client smoke, real auth, cleanup, concurrent and abandoned-run isolation');
} finally { await deleteApp(app); }
