import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';
import {ref, uploadBytes, getBytes, getMetadata, deleteObject, updateMetadata} from 'firebase/storage';
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {getStorage} from 'firebase-admin/storage';
import {emulatorAddress, requireDemo} from '../../tool/firebase/common.mjs';
import {prepareSupportAttachment, submitSupportTicket, deliverSupportNotification, retrySupportNotifications, deleteSupportData, cleanupSupportUploads, approvedSupportRecipient} from '../src/support-tickets.js';
const projectId = requireDemo(process.env.GCLOUD_PROJECT);
const env = await initializeTestEnvironment({projectId,
  firestore: {...emulatorAddress(process.env.FIRESTORE_EMULATOR_HOST), rules: readFileSync('firestore.rules', 'utf8')},
  database: {...emulatorAddress(process.env.FIREBASE_DATABASE_EMULATOR_HOST), rules: readFileSync('database.rules.json', 'utf8')},
  storage: {...emulatorAddress(process.env.FIREBASE_STORAGE_EMULATOR_HOST), rules: readFileSync('storage.rules', 'utf8')},
});
const app = initializeApp({projectId, databaseURL: `https://${projectId}.firebaseio.com`, storageBucket: `${projectId}.firebasestorage.app`}, 'support-test');
const db = getFirestore(app), realtime = getDatabase(app), bucket = getStorage(app).bucket(), now = Date.now();
const auth = {uid: 'support-owner', token: {firebase: {sign_in_provider: 'password'}}};
const owner = env.authenticatedContext(auth.uid, auth.token), other = env.authenticatedContext('support-other', auth.token), operator = env.authenticatedContext('support-operator', {supportOperator: true}), anon = env.authenticatedContext('support-anonymous', {firebase: {sign_in_provider: 'anonymous'}});
const storage = context => context.storage(`gs://${projectId}.firebasestorage.app`);
const input = (requestId, extra = {}) => ({accountId: auth.uid, requestId, message: '문의 내용', replyEmail: 'reply@example.test', diagnostics: {}, attachments: [], ...extra});
const submit = (payload, overrides = {}) => submitSupportTicket({db, realtime, bucket, auth, payload, now, ...overrides});
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=', 'base64');
const attachment = (requestId, extra = {}) => ({accountId: auth.uid, requestId, fileId: 'screenshot-0001', contentType: 'image/png', sizeBytes: png.length, sha256: createHash('sha256').update(png).digest('hex'), ...extra});
const prepare = (payload, overrides = {}) => prepareSupportAttachment({db, auth, payload, now, ...overrides});
const ticketPath = id => `users/${auth.uid}/supportTickets/${id}`;
const config = {enabled: true, provider: 'resend', recipientEmail: approvedSupportRecipient, fromEmail: 'support@example.test'};
let assertions = 0;
const pass = name => {assertions++; console.log(`PASS support: ${name}`);};
try {
  // A retry after a lost callable response must create one ticket/outbox/quota.
  const requests = await Promise.all(Array.from({length: 5}, () => submit(input('request-concurrent'))));
  assert.equal(requests.filter(r => !r.duplicate).length, 1);
  assert.equal((await db.collection('supportNotificationOutbox').get()).size, 1);
  assert.equal((await db.doc(`supportRateLimits/${auth.uid}`).get()).data().tickets.length, 1);
  await assert.rejects(submit(input('request-concurrent', {message: 'changed'})), {code: 'already-exists'});
  await assert.rejects(submit(input('request-mismatch', {accountId: 'other'})), {code: 'permission-denied'});
  await assert.rejects(submit(input('request-anonymous'), {auth: {uid: auth.uid, token: {firebase: {sign_in_provider: 'anonymous'}}}}), {code: 'permission-denied'});
  pass('concurrent persist-first idempotency, changed payload conflict, account/anonymous boundaries');

  const ticket = doc(owner.firestore(), ticketPath('request-concurrent'));
  await assertSucceeds(getDoc(ticket));
  await assertSucceeds(getDoc(doc(operator.firestore(), ticket.path)));
  for (const context of [other, anon, env.unauthenticatedContext()]) await assertFails(getDoc(doc(context.firestore(), ticket.path)));
  for (const context of [owner, other, operator]) {
    await assertFails(setDoc(doc(context.firestore(), ticket.path), {notificationStatus: 'sent'}));
    await assertFails(setDoc(doc(context.firestore(), 'supportConfig/email'), config));
    await assertFails(setDoc(doc(context.firestore(), `users/${auth.uid}/supportUploads/forged-000`), {status: 'ready'}));
    await assertFails(getDoc(doc(context.firestore(), 'supportNotificationOutbox/private')));
  }
  pass('owner/operator read only, other/anonymous denied, private outbox/config/permit writes denied');

  await assert.rejects(submit(input('request-foreign-tv', {diagnostics: {tvs: [{deviceId: 'foreign-tv'}]}})), {code: 'permission-denied'});
  await realtime.ref(`users/${auth.uid}/devices/my-tv`).set({name: 'TV'});
  const diagnostics = {errorId: 'error-support-01', operationId: 'operation-01', preparationStage: 'image', stack: 'private', token: 'hidden', tvs: [{deviceId: 'my-tv', appVersion: '1.1.1', preparationStatus: 'failed', checkedAtMs: now - 1000, secret: 'hidden'}]};
  await submit(input('request-own-tv', {diagnostics}));
  const stored = (await db.doc(ticketPath('request-own-tv')).get()).data();
  assert.equal(stored.diagnostics.tvs[0].preparationStatus, 'failed'); assert.equal(stored.diagnostics.preparationStage, 'image');
  assert.doesNotMatch(JSON.stringify(stored), /private|hidden/);
  await realtime.ref(`users/${auth.uid}/devices/my-tv`).remove();
  assert.equal((await submit(input('request-own-tv', {diagnostics}))).duplicate, true);
  pass('actual owned TV diagnostics, allowlist, retry survives TV unpair');

  const permitPayload = attachment('request-screenshot');
  const {path} = await prepare(permitPayload);
  const image = ref(storage(owner), path);
  await assert.rejects(getMetadata(image), error => error.code === 'storage/object-not-found');
  await assertFails(uploadBytes(ref(storage(owner), path.replace('request-screenshot', 'request-forged')), png, {contentType: 'image/png', customMetadata: {sha256: permitPayload.sha256}}));
  await assertFails(uploadBytes(ref(storage(other), path), png, {contentType: 'image/png', customMetadata: {sha256: permitPayload.sha256}}));
  await assertFails(uploadBytes(image, png, {contentType: 'image/jpeg', customMetadata: {sha256: permitPayload.sha256}}));
  await assertFails(uploadBytes(image, png, {contentType: 'image/png', customMetadata: {sha256: 'bad'}}));
  await assertSucceeds(uploadBytes(image, png, {contentType: 'image/png', customMetadata: {sha256: permitPayload.sha256}}));
  await assertFails(uploadBytes(image, png, {contentType: 'image/png', customMetadata: {sha256: permitPayload.sha256}}));
  await assertFails(updateMetadata(image, {customMetadata: {sha256: 'tamper'}}));
  await assertFails(deleteObject(image));
  await assertFails(getBytes(ref(storage(other), path)));
  assert.equal((await assertSucceeds(getBytes(ref(storage(operator), path)))).byteLength, png.length);
  const accepted = await submit(input('request-screenshot', {attachments: [{path}]}));
  assert.equal(accepted.notificationStatus, 'queued');
  assert.deepEqual(await prepare(permitPayload, {now: now + 86400000}), {path});
  assert.equal((await getMetadata(image)).customMetadata.sha256, permitPayload.sha256);
  assert.equal((await submit(input('request-screenshot', {attachments: [{path}]}))).duplicate, true);
  await assert.rejects(submit(input('request-theft', {attachments: [{path}]})), {code: 'permission-denied'});
  await assert.rejects(prepare({...permitPayload, sha256: 'a'.repeat(64)}), {code: 'already-exists'});
  await assert.rejects(prepare(attachment('request-huge', {sizeBytes: 5 * 1024 * 1024 + 1})), {code: 'invalid-argument'});
  pass('prepared immutable screenshot, missing-owner metadata, MIME/hash/size/ownership rules, response-lost retry');

  const bad = attachment('request-badbytes');
  await prepare(bad);
  await bucket.file(`users/${auth.uid}/support/${bad.requestId}/${bad.fileId}`).save(Buffer.from('not PNG'), {metadata: {contentType: bad.contentType, metadata: {sha256: bad.sha256}}});
  await assert.rejects(submit(input(bad.requestId, {attachments: [{path: `users/${auth.uid}/support/${bad.requestId}/${bad.fileId}`}]})), {code: 'invalid-argument'});
  assert.equal((await db.doc(ticketPath(bad.requestId)).get()).exists, false);
  const expired = attachment('request-expired');
  const expiredPath = (await prepare(expired, {now: now - 1000000})).path;
  await assertFails(uploadBytes(ref(storage(owner), expiredPath), png, {contentType: 'image/png', customMetadata: {sha256: expired.sha256}}));
  const cleaned = await cleanupSupportUploads({db, bucket, now: now + 86400001});
  assert.equal(cleaned, 2); assert.equal((await bucket.file(path).exists())[0], true, 'submitted screenshot retained');
  pass('server byte validation and abandoned permit cleanup preserve submitted attachment');

  // Five per hour, twenty per day, each accepted request counted once.
  const rateAuth = {uid: 'rate-owner', token: auth.token};
  for (let hour = 0; hour < 4; hour++) {
    for (let i = 0; i < 5; i++) await submit(input(`rate-request-${hour}-${i}`, {accountId: rateAuth.uid}), {auth: rateAuth, now: now + hour * 3600001});
    await assert.rejects(submit(input(`rate-extra-${hour}`, {accountId: rateAuth.uid}), {auth: rateAuth, now: now + hour * 3600001}), {code: 'resource-exhausted'});
  }
  await assert.rejects(submit(input('rate-daily-extra', {accountId: rateAuth.uid}), {auth: rateAuth, now: now + 5 * 3600000}), {code: 'resource-exhausted'});
  for (let i = 0; i < 5; i++) await prepare(attachment(`upload-rate-${i}`, {accountId: rateAuth.uid}), {auth: rateAuth});
  await assert.rejects(prepare(attachment('upload-rate-extra', {accountId: rateAuth.uid}), {auth: rateAuth}), {code: 'resource-exhausted'});
  pass('independent submission/upload hourly and daily quotas');

  const outbox = (await db.collection('supportNotificationOutbox').where('requestId', '==', 'request-concurrent').get()).docs[0];
  let sends = 0; const delivery = {db, id: outbox.id, config, projectId, now};
  await Promise.all(Array.from({length: 5}, () => deliverSupportNotification({...delivery, send: async () => {sends++; throw new Error('response lost');}})));
  assert.equal(sends, 1);
  assert.equal((await db.doc(ticket.path).get()).data().notificationStatus, 'retrying');
  let retryKey, retryBody;
  await deliverSupportNotification({...delivery, now: now + 60001, send: async (body, key) => {sends++; retryBody = body; retryKey = key; return 'fake-provider-id';}});
  assert.equal(retryKey, outbox.data().providerKey);
  assert.deepEqual(retryBody, (await outbox.ref.get()).data().envelope);
  assert.equal((await submit(input('request-concurrent'))).notificationStatus, 'sent');
  await deliverSupportNotification({...delivery, now: now + 120000, send: async () => {sends++;}});
  assert.equal(sends, 2);
  // Scheduler handles unavailable configuration while preserving tickets.
  await retrySupportNotifications({db, config: {}, projectId, now: now + 200000, send: null});
  assert.equal((await db.doc(ticketPath('request-own-tv')).get()).data().notificationStatus, 'retrying');
  pass('real transaction mail lease, immutable provider retry key/body, scheduler config failure preserves ticket');

  await db.doc(`accountDeletions/${auth.uid}`).set({status: 'processing'});
  await assert.rejects(submit(input('request-after-delete')), {code: 'permission-denied'});
  await assert.rejects(prepare(attachment('request-after-delete')), {code: 'permission-denied'});
  await assertFails(getDoc(ticket)); await assertFails(getDoc(doc(operator.firestore(), ticket.path)));
  await assertFails(getBytes(image));
  const deletionOutbox = (await db.collection('supportNotificationOutbox').where('requestId', '==', 'request-own-tv').get()).docs[0];
  await deliverSupportNotification({...delivery, id: deletionOutbox.id, now: now + 2000000, send: async () => assert.fail('deleted account must not send')});
  assert.equal((await deletionOutbox.ref.get()).data().status, 'cancelled');
  await deleteSupportData(db, auth.uid); await bucket.deleteFiles({prefix: `users/${auth.uid}/`}); await db.recursiveDelete(db.doc(`users/${auth.uid}`));
  assert.equal((await db.collection('supportNotificationOutbox').where('ownerId', '==', auth.uid).get()).empty, true);
  assert.equal((await db.doc(`supportRateLimits/${auth.uid}`).get()).exists, false);
  assert.equal((await db.doc(ticket.path).get()).exists, false);
  assert.equal((await bucket.getFiles({prefix: `users/${auth.uid}/`}))[0].length, 0);
  pass('deletion lock blocks reads/submits/sends and account cleanup removes tickets/outbox/permits/files');
  console.log(`PASS support contracts: ${assertions} groups; all provider calls injected, no external emails`);
} finally {await env.cleanup(); await app.delete();}
