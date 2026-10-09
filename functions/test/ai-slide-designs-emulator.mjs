import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, getDocs, collection, setDoc, deleteDoc, serverTimestamp, setLogLevel} from 'firebase/firestore';
import {handleAiSlideDesigns, readSlideDesignPrompt} from '../src/ai-slide-designs.js';
import {handleAiSlides} from '../src/ai-slides.js';
import {AI_TIMER_RESERVE} from '../src/ai-timer.js';

// Never run against a production project, even if ambient credentials exist.
assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
setLogLevel('silent'); // Expected rules denials are asserted below, not runtime errors.
const projectId = 'demo-cloudboard-design-tests';
const app = initializeApp({projectId}), db = getFirestore(app);
const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
const env = await initializeTestEnvironment({projectId,
  firestore: {host, port: Number(port), rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')},
});
const now = Date.parse('2026-10-09T00:00:00Z');
const theme = () => ({schemaVersion: 1, designBackgroundColor: 0xFFFAFAFA, designTextColor: 0xFF121212,
  designAccentColor: 0xFF3355BB, designLayout: 'auto', designFontWeight: 700, designItalic: false,
  designSpacing: 1, showTimer: false, timerX: .84, timerY: .5, timerSize: 1,
  designStyle: {version: 1, family: 'editorial', fontFamily: 'serif', titleColor: 0xFF223388, titleWeight: 900, motif: ''}});
const template = (storeId = 'owner-center') => ({schemaVersion: 1, name: 'Morning class', description: 'Clear class poster',
  storeId, theme: theme(), updatedAt: serverTimestamp()});
const style = family => ({name: `${family} design`, description: 'Clear workout hierarchy', family,
  backgroundColor: 0xFFFAFAFA, textColor: 0xFF121212, accentColor: 0xFF3355BB, titleColor: family === 'banner' ? 0xFFFFFFFF : 0xFF223388,
  fontFamily: 'sans', titleWeight: 900, bodyWeight: 700, italic: false, spacing: 1, motif: ''});
const designs = {designs: ['banner', 'focus', 'editorial'].map(style), warnings: []};
const content = {complete: true, slides: [{title: 'RUN', layout: 'list', sourceTitleLineIds: [],
  sections: [{heading: '', lines: ['Run 1km'], sourceLineIds: [1]}], workSeconds: null, restSeconds: null, sets: null}], warnings: []};
const input = {action: 'generate', prompt: 'Run 1km'};
const grant = uid => db.doc(`subscriptionEntitlements/${uid}`).set({plan: 'premium', status: 'active', validUntilMs: now + 86400000});
const options = uid => ({db, uid, apiKey: 'fake-test-key', input, now});

try {
  await env.clearFirestore();
  await db.doc('centers/owner-center').set({ownerUid: 'owner'});
  await db.doc('centers/other-center').set({ownerUid: 'other'});
  const owner = env.authenticatedContext('owner').firestore();
  const other = env.authenticatedContext('other').firestore();
  const guest = env.unauthenticatedContext().firestore();
  const path = 'users/owner/aiSlideDesigns/ai-design-test';
  await assertSucceeds(setDoc(doc(owner, path), template()));
  assert.equal((await assertSucceeds(getDoc(doc(owner, path)))).data().theme.designStyle.family, 'editorial');
  await assertSucceeds(getDocs(collection(owner, 'users/owner/aiSlideDesigns')));
  await assertSucceeds(setDoc(doc(owner, path), template(null)));
  for (const client of [other, guest]) {
    await assertFails(getDoc(doc(client, path)));
    await assertFails(getDocs(collection(client, 'users/owner/aiSlideDesigns')));
    await assertFails(setDoc(doc(client, path), template()));
    await assertFails(deleteDoc(doc(client, path)));
  }
  for (const storeId of ['other-center', 'missing-center', '', 'owner/center', 12]) {
    await assertFails(setDoc(doc(owner, path), template(storeId)));
  }
  for (const invalid of [{schemaVersion: 2}, {name: ''}, {name: 'a'.repeat(61)}, {description: 'a'.repeat(161)},
    {prompt: 'private lesson'}, {workSeconds: 30}, {updatedAt: new Date(0)}]) {
    await assertFails(setDoc(doc(owner, path), {...template(), ...invalid}));
  }
  for (const invalid of [{family: 'freeform'}, {fontFamily: 'arbitrary'}, {titleWeight: 750}, {motif: 'a'.repeat(13)},
    {version: 2}, {titleColor: 0x00FFFFFF}, {titleColor: 0x100000000}, {exercise: 'Run 1km'},
    {originalTemplate: 'unknown'}, {originalTemplate: 1}]) {
    const value = template(); value.theme.designStyle = {...value.theme.designStyle, ...invalid};
    await assertFails(setDoc(doc(owner, path), value));
  }
  for (const invalid of [{designLayout: 'absolute'}, {timerX: 2}, {designSpacing: .7}, {updatedAt: serverTimestamp()}]) {
    const value = template(); value.theme = {...value.theme, ...invalid};
    await assertFails(setDoc(doc(owner, path), value));
  }
  const withoutStyle = theme(); delete withoutStyle.designStyle;
  for (const value of [withoutStyle, {...theme(), designStyle: null}, {...theme(), designStyle: {titleColor: null}},
    {...theme(), designStyle: {...theme().designStyle, originalTemplate: null}},
    {...theme(), designStyle: {...theme().designStyle, originalTemplate: 'dolpa-brick-v1'}}, theme()]) {
    await assertSucceeds(setDoc(doc(owner, 'users/owner/settings/aiSlidesTheme'), {...value, updatedAt: serverTimestamp()}));
    await assertSucceeds(setDoc(doc(owner, path), {...template(), theme: value}));
  }
  // Existing server-only slide-library semantics must remain unchanged.
  await assertFails(setDoc(doc(owner, 'users/owner/slideStyles/ai-design-test'), template()));
  await assertFails(setDoc(doc(owner, 'centers/owner-center'), {ownerUid: 'owner'}));
  await assertSucceeds(deleteDoc(doc(owner, path)));
  await db.doc('accountDeletions/owner').set({status: 'pending'});
  await assertFails(getDoc(doc(owner, 'users/owner/settings/aiSlidesTheme')));
  await assertFails(setDoc(doc(owner, path), template()));
  console.log('PASS design rules: isolated owner, center ownership, legacy compatibility, strict tokens, timestamps, deletion, unchanged library');

  await grant('metered');
  let designCalls = 0;
  const recognize = async () => {designCalls++; return {result: designs, costMicros: 500};};
  const status = await handleAiSlideDesigns({...options('metered'), input: {action: 'access'}});
  assert.equal(status.limit, 30); assert.equal(status.remaining, 30);
  const concurrent = await Promise.allSettled([
    handleAiSlideDesigns({...options('metered'), recognize}),
    handleAiSlideDesigns({...options('metered'), recognize}),
  ]);
  assert(concurrent.some(r => r.status === 'fulfilled'));
  assert.equal(designCalls, 1, 'identical concurrent designs must cause only one provider request');
  assert.equal((await db.doc('users/metered/aiSlidesUsage/2026-10').get()).data().used, 1);
  assert.equal((await handleAiSlideDesigns({...options('metered'), recognize})).cached, true);
  const lesson = await handleAiSlides({...options('metered'), now: now + 6000,
    recognize: async () => ({result: content, costMicros: 500})});
  assert.equal(lesson.remaining, 28);
  assert.equal((await db.collection('users/metered/aiSlidesJobs').get()).size, 2, 'style and lesson jobs have distinct cache keys');
  assert.equal((await db.doc('aiTimerBudgets/2026-10').get()).data().spentMicros, 1000);
  await db.doc('users/metered/aiSlidesUsage/2026-10').update({used: 30});
  assert.equal((await handleAiSlideDesigns({...options('metered'), recognize})).cached, true, 'completed cache remains free at the quota limit');
  await assert.rejects(handleAiSlideDesigns({...options('metered'), now: now + 12000,
    input: {...input, prompt: 'fresh design'}, recognize}), error => error.details.reason === 'user-limit');

  await grant('last-slot');
  await db.doc('users/last-slot/aiSlidesUsage/2026-10').set({used: 29, attempts: 29, lastAttemptMs: now - 6000});
  let lastCalls = 0;
  const finalSlot = await Promise.allSettled([
    handleAiSlideDesigns({...options('last-slot'), recognize: async () => {lastCalls++; return {result: designs, costMicros: 500};}}),
    handleAiSlides({...options('last-slot'), recognize: async () => {lastCalls++; return {result: content, costMicros: 500};}}),
  ]);
  assert.equal(finalSlot.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(lastCalls, 1, 'content and design calls compete atomically for the same last slot');
  assert.equal((await db.doc('users/last-slot/aiSlidesUsage/2026-10').get()).data().used, 30);

  await grant('failure');
  const spentBefore = (await db.doc('aiTimerBudgets/2026-10').get()).data().spentMicros;
  await assert.rejects(handleAiSlideDesigns({...options('failure'), recognize: async () => ({
    result: {...designs, designs: designs.designs.map(d => ({...d, textColor: d.backgroundColor}))}, costMicros: 1})}),
    error => error.details.reason === 'unreadable-design-palette');
  assert.equal((await db.doc('users/failure/aiSlidesUsage/2026-10').get()).data().used, 0);
  assert.equal((await db.doc('aiTimerBudgets/2026-10').get()).data().spentMicros, spentBefore + AI_TIMER_RESERVE);
  const key = readSlideDesignPrompt(input).key;
  assert.equal((await db.doc(`users/failure/aiSlidesJobs/${key}`).get()).data().status, 'failed');
  await assert.rejects(handleAiSlideDesigns({...options('free'), recognize}), {code: 'permission-denied'});
  await db.doc('subscriptionEntitlements/metered').update({plan: 'free'});
  await assert.rejects(handleAiSlideDesigns({...options('metered'), recognize}), {code: 'permission-denied'});
  await db.doc('appConfig/aiSlides').set({enabled: false});
  await assert.rejects(handleAiSlideDesigns({...options('last-slot'), recognize}), {code: 'failed-precondition'});
  const metered = env.authenticatedContext('metered').firestore();
  for (const restricted of ['users/metered/aiSlidesUsage/2026-10', `users/metered/aiSlidesJobs/${key}`, 'appConfig/aiSlides']) {
    await assertFails(getDoc(doc(metered, restricted)));
    await assertFails(setDoc(doc(metered, restricted), {used: 0, enabled: true}));
  }
  console.log('PASS design metering: real transactions, concurrent dedupe, shared content quota/budget, last-slot race, cache, refund, premium, kill switch');
} finally {
  await env.cleanup();
  await deleteApp(app);
}
