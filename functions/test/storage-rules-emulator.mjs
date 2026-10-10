import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {ref, uploadBytes, getBytes, getMetadata, deleteObject} from 'firebase/storage';
import {doc, setDoc} from 'firebase/firestore';
import {emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';

const projectId = requireDemo(process.env.GCLOUD_PROJECT);
const env = await initializeTestEnvironment({projectId,
  firestore: {...emulatorAddress(process.env.FIRESTORE_EMULATOR_HOST), rules: readFileSync('firestore.rules', 'utf8')},
  storage: {...emulatorAddress(process.env.FIREBASE_STORAGE_EMULATOR_HOST), rules: readFileSync('storage.rules', 'utf8')},
});
const bucket = `gs://${projectId}.firebasestorage.app`;
const owner = env.authenticatedContext('owner').storage(bucket);
const denied = [env.authenticatedContext('other'), env.unauthenticatedContext(), env.authenticatedContext('tv', {firebase: {sign_in_provider: 'anonymous'}})];
try {
  for (const [path, max] of [['profile', 5], ['brand', 10], ['workouts/w', 10]]) {
    const name = `users/owner/${path}/test.png`, target = ref(owner, name);
    await assertSucceeds(uploadBytes(target, new Uint8Array([1, 2]), {contentType: 'image/png'}));
    assert.equal((await assertSucceeds(getBytes(target))).byteLength, 2);
    await assertSucceeds(uploadBytes(target, new Uint8Array([3]), {contentType: 'image/jpeg'}));
    for (const context of denied) {
      const foreign = ref(context.storage(bucket), name);
      await assertFails(getMetadata(foreign));
      await assertFails(uploadBytes(foreign, new Uint8Array([1]), {contentType: 'image/png'}));
      await assertFails(deleteObject(foreign));
    }
    await assertFails(uploadBytes(target, new Uint8Array([1]), {contentType: 'text/plain'}));
    await assertFails(uploadBytes(target, new Uint8Array(max * 1024 * 1024), {contentType: 'image/png'}));
    await assertSucceeds(uploadBytes(target, new Uint8Array(max * 1024 * 1024 - 1), {contentType: 'image/png'}));
    await assertSucceeds(deleteObject(target));
    console.log(`PASS storage ${path}: owner CRUD, cross-owner/guest/TV, MIME and strict size boundary`);
  }
  const target = ref(owner, 'users/owner/workouts/w/lock.png');
  await uploadBytes(target, new Uint8Array([1]), {contentType: 'image/png'});
  await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'accountDeletions/owner'), {status: 'pending'}));
  await assertFails(getBytes(target));
  await assertFails(uploadBytes(target, new Uint8Array([1]), {contentType: 'image/png'}));
  await assertFails(deleteObject(target));
  await assertSucceeds(uploadBytes(ref(env.authenticatedContext('other').storage(bucket), 'users/other/profile/ok.png'), new Uint8Array([1]), {contentType: 'image/png'}));
  console.log('PASS storage deletion lock: stale owner denied; other account preserved');
} finally { await env.cleanup(); }
