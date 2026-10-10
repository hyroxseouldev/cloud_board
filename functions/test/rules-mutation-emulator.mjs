import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, writeBatch, Timestamp} from 'firebase/firestore';
import {emulatorAddress, requireDemo, writeJson} from '../../tool/firebase/common.mjs';
const started = Date.now();
const original = readFileSync('firestore.rules', 'utf8');
const exported = JSON.parse(readFileSync('build/contracts/workout-save-current.json', 'utf8'), (_, value) => value?.__timestampMillis !== undefined ? Timestamp.fromMillis(value.__timestampMillis) : value);
const fixture = exported.scenarios[0].writes[0];
const config = {projectId: requireDemo(process.env.GCLOUD_PROJECT), firestore: emulatorAddress(process.env.FIRESTORE_EMULATOR_HOST)};
async function check(rules, kind) {
  const env = await initializeTestEnvironment({...config, firestore: {...config.firestore, rules}});
  try {
    const client = env.authenticatedContext(kind === 'availability' ? 'owner' : 'other').firestore();
    const batch = writeBatch(client);
    batch.set(doc(client, `users/owner/workouts/${fixture.workout.id}`), fixture.workout);
    batch.set(doc(client, `users/owner/workoutSummaries/${fixture.summary.id}`), fixture.summary);
    if (kind === 'availability') await assertSucceeds(batch.commit());
    else await assertFails(batch.commit());
  } finally { await env.cleanup(); }
}
const results = [];
try {
  await check(original, 'availability'); await check(original, 'isolation');
  for (const [kind, allow] of [['availability', 'false'], ['isolation', 'true']]) {
    const injected = Date.now();
    const bad = `rules_version = '2'; service cloud.firestore { match /databases/{db}/documents { match /{all=**} { allow read, write: if ${allow}; } } }`;
    await assert.rejects(check(bad, kind), error => kind === 'availability'
      ? error.code === 'permission-denied' : /Expected request to fail/.test(error.message));
    results.push({kind, detected: true, detectionMs: Date.now() - injected});
  }
} finally {
  await check(original, 'availability'); await check(original, 'isolation');
}
writeJson('build/firebase-contracts/recovery-drill.json', {format: 1, environment: 'emulator', status: 'success', results,
  restored: true, durationMs: Date.now() - started});
console.log('PASS: deny-all and allow-all mutations were detected; original rules restored and both contracts rechecked');
