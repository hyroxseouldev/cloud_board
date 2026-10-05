import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, deleteDoc, serverTimestamp} from 'firebase/firestore';

assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
const env = await initializeTestEnvironment({
  projectId: 'demo-cloudboard-ai',
  firestore: {host, port: Number(port), rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')},
});
const theme = () => ({
  schemaVersion: 1, designBackgroundColor: 0xFF000000, designTextColor: 0xFFFFFFFF,
  designAccentColor: 0xFFFF3333, designLayout: 'cards', designFontWeight: 700,
  designItalic: false, designSpacing: 1.15, showTimer: true,
  timerX: 0.84, timerY: 0.5, timerSize: 1, updatedAt: serverTimestamp(),
});
try {
  await env.clearFirestore();
  const owner = env.authenticatedContext('owner').firestore();
  const other = env.authenticatedContext('other').firestore();
  const guest = env.unauthenticatedContext().firestore();
  const path = 'users/owner/settings/aiSlidesTheme';
  await assertSucceeds(setDoc(doc(owner, path), theme()));
  const saved = await assertSucceeds(getDoc(doc(owner, path)));
  assert.equal(saved.data().designLayout, 'cards');
  await assertSucceeds(setDoc(doc(owner, path), {...theme(), designLayout: 'columns', designAccentColor: null}));
  for (const db of [other, guest]) {
    await assertFails(getDoc(doc(db, path)));
    await assertFails(setDoc(doc(db, path), theme()));
    await assertFails(deleteDoc(doc(db, path)));
  }
  for (const invalid of [
    {prompt: 'private lesson'}, {workSeconds: 60}, {subscriptionPlan: 'premium'},
    {schemaVersion: 2}, {designLayout: 'unknown'}, {designFontWeight: 50},
    {designSpacing: 0.79}, {designSpacing: 1.51}, {timerX: -0.1}, {timerY: 1.1},
    {timerSize: 0.49}, {timerSize: 1.81}, {designBackgroundColor: -1},
    {designAccentColor: 4294967296}, {showTimer: 'yes'}, {designItalic: 'yes'},
    {updatedAt: new Date(0)},
  ]) {
    await assertFails(setDoc(doc(owner, path), {...theme(), ...invalid}));
  }
  await assertSucceeds(deleteDoc(doc(owner, path)));
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'accountDeletions/owner'), {status: 'pending'});
  });
  await assertFails(setDoc(doc(owner, path), theme()));
  await assertFails(getDoc(doc(owner, path)));
  console.log('PASS AI slide theme: owner isolation, strict visual-only schema/bounds, server timestamp, delete, account deletion');
} finally {
  await env.cleanup();
}
