import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, setDoc, deleteDoc, updateDoc, setLogLevel} from 'firebase/firestore';
import {ref, uploadBytes, getBytes, deleteObject, updateMetadata, listAll} from 'firebase/storage';

function localAddress(value) {
  assert.match(value || '', /^(127\.0\.0\.1|localhost):\d+$/);
  const [host, port] = value.split(':');
  return {host, port: Number(port)};
}
const projectId = process.env.GCLOUD_PROJECT;
assert.match(projectId || '', /^demo-/);
setLogLevel('silent');
const env = await initializeTestEnvironment({projectId,
  firestore: {...localAddress(process.env.FIRESTORE_EMULATOR_HOST), rules: readFileSync('firestore.rules', 'utf8')},
  storage: {...localAddress(process.env.FIREBASE_STORAGE_EMULATOR_HOST), rules: readFileSync('storage.rules', 'utf8')},
});
const bucket = `gs://${projectId}.firebasestorage.app`;
const signedIn = {firebase: {sign_in_provider: 'password'}};
const owner = env.authenticatedContext('owner', signedIn);
const stranger = env.authenticatedContext('stranger', signedIn);
const anonymousOwner = env.authenticatedContext('owner', {firebase: {sign_in_provider: 'anonymous'}});
const display = env.authenticatedContext('display', {firebase: {sign_in_provider: 'anonymous'}, accountOwnerId: 'owner'});
const operatorClaim = env.authenticatedContext('operator', {...signedIn, admin: true, supportOperator: true});
const guest = env.unauthenticatedContext();
const catalogPath = 'centers/center-one/slideTemplateCatalog/current';
const imagePath = `center-templates/center-one/template-one/${'a'.repeat(64)}.png`;
const otherImagePath = `center-templates/center-two/template-one/${'a'.repeat(64)}.png`;
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=', 'base64');
const catalog = {schemaVersion: 1, revision: 1, centerName: '', templates: []};
try {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'centers/center-one'), {ownerUid: 'owner'});
    await setDoc(doc(context.firestore(), 'centers/center-two'), {ownerUid: 'stranger'});
    await setDoc(doc(context.firestore(), catalogPath), catalog);
    await setDoc(doc(context.firestore(), 'centers/center-one/slideTemplateCatalog/draft'), catalog);
    await setDoc(doc(context.firestore(), 'centers/center-two/slideTemplateCatalog/current'), catalog);
    await setDoc(doc(context.firestore(), 'users/owner/slideTemplates/private'), {value: {name: 'Private'}});
    await uploadBytes(ref(context.storage(bucket), imagePath), png, {contentType: 'image/png'});
    await uploadBytes(ref(context.storage(bucket), otherImagePath), png, {contentType: 'image/png'});
  });
  assert.deepEqual((await assertSucceeds(getDoc(doc(owner.firestore(), catalogPath)))).data(), catalog);
  assert.equal((await assertSucceeds(getBytes(ref(owner.storage(bucket), imagePath)))).byteLength, png.length);
  for (const context of [stranger, anonymousOwner, display, operatorClaim, guest]) {
    await assertFails(getDoc(doc(context.firestore(), catalogPath)));
    await assertFails(getBytes(ref(context.storage(bucket), imagePath)));
  }
  await assertFails(getDoc(doc(owner.firestore(), 'centers/center-two/slideTemplateCatalog/current')));
  await assertFails(getBytes(ref(owner.storage(bucket), otherImagePath)));
  for (const context of [owner, stranger, anonymousOwner, display, operatorClaim, guest]) {
    await assertFails(getDocs(collection(context.firestore(), 'centers/center-one/slideTemplateCatalog')));
    await assertFails(getDoc(doc(context.firestore(), 'centers/center-one/slideTemplateCatalog/draft')));
    await assertFails(setDoc(doc(context.firestore(), catalogPath), {...catalog, revision: 2}));
    await assertFails(updateDoc(doc(context.firestore(), catalogPath), {revision: 2}));
    await assertFails(deleteDoc(doc(context.firestore(), catalogPath)));
    await assertFails(setDoc(doc(context.firestore(), 'centers/center-one/slideTemplateCatalog/draft'), catalog));
    await assertFails(uploadBytes(ref(context.storage(bucket), imagePath), png));
    await assertFails(uploadBytes(ref(context.storage(bucket), imagePath.replace('a'.repeat(64), 'b'.repeat(64))), png));
    await assertFails(updateMetadata(ref(context.storage(bucket), imagePath), {customMetadata: {firebaseStorageDownloadTokens: 'forged'}}));
    await assertFails(deleteObject(ref(context.storage(bucket), imagePath)));
    await assertFails(listAll(ref(context.storage(bucket), 'center-templates/center-one/template-one')));
  }
  await assertSucceeds(getDoc(doc(owner.firestore(), 'users/owner/slideTemplates/private')));
  await assertFails(getDoc(doc(stranger.firestore(), 'users/owner/slideTemplates/private')));
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'accountDeletions/owner'), {status: 'pending'});
  });
  await assertFails(getDoc(doc(owner.firestore(), catalogPath)));
  await assertFails(getBytes(ref(owner.storage(bucket), imagePath)));
  console.log('PASS center template rules: exact owner get, anonymous/display/stranger isolation, catalog and asset list/write denial, deletion lock, unchanged private library');
} finally {
  await env.cleanup();
}
