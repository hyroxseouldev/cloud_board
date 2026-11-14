// Opt-in local integration: real Firestore/RTDB/Storage, injected actor/clock.
// No callable, app, deployed backend or production-success claim.
import test from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {getStorage} from 'firebase-admin/storage';
import {handleClassAdmission, setUsageEnrollment} from '../src/class-admission.js';
import {readUsage, requireUsageContext, reserveTransfer} from '../src/image-usage-ledger.js';
import {imageUsagePolicyRevision, usagePeriods} from '../src/image-usage-policy.js';
import {handleMedia, handleMediaLease} from '../src/media-gateway.js';
import {hashBytes} from '../src/managed-image-assets.js';
import {png, serve} from './media-gateway-fixtures.js';

const enabled = process.env.USAGE_SUBSET_TEST === '1';
const projectId = 'demo-cloudboard-subset';
const reason = (promise, value) => assert.rejects(promise, error => error.details?.reason === value);

test('prechecked cohort selection preserves admission and restricts playback', {skip: !enabled}, async t => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_DATABASE_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST']) {
    assert.match(process.env[key] ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
  }
  const app = initializeApp({projectId, databaseURL: `https://${projectId}-default-rtdb.firebaseio.com`,
    storageBucket: `${projectId}.appspot.com`}, 'subset-contracts');
  const db = getFirestore(app), realtime = getDatabase(app), bucket = getStorage(app).bucket();
  const baseNow = Date.parse('2026-11-14T03:00:00Z');
  let fixtureNumber = 0;
  async function fixture() {
    const ownerId = `subset-owner-${++fixtureNumber}`, user = realtime.ref(`users/${ownerId}`);
    let now = baseNow;
    const ctx = {db, realtime, bucket, projectId, clock: () => now, emulator: true,
      mediaBaseUrl: `http://127.0.0.1:5008/${projectId}/asia-northeast3/cloudboardMedia`,
      auth: {verifyIdToken: async uid => ({uid})}};
    const actor = {uid: ownerId, token: {firebase: {sign_in_provider: 'password'}}};
    const uid = id => `${ownerId}-${id}`;
    await db.doc(`imageUsageAccounts/${ownerId}`).set({mode: 'legacy', revision: 0, inventoryComplete: true,
      eligibility: {tokenFree: true, rulesReady: true}, storageUsedBytes: 0, storageReservedBytes: 0, storageUnknownBytes: 0});
    await db.doc(`subscriptionEntitlements/${ownerId}`).set({plan: 'premium', canStartClass: true,
      status: 'active', validUntilMs: baseNow + 86400000});
    await user.set({operations: {unchanged: 'keep'}, devices: Object.fromEntries(['a', 'b'].map(id => [id, {
      id, paired: true, displayUid: uid(id), pairingCode: '123456', pairedAtMs: baseNow - 1000,
      imageUsageProtocol: 1, preparationProtocol: 2, playbackProtocol: 5, displayState: 'auto',
      online: true, lastSeenAtMs: baseNow,
    }]))});
    for (const id of ['a', 'b']) await realtime.ref(`displayAccess/${uid(id)}`).set({ownerId, deviceId: id,
      pairingCode: '123456', pairedAtMs: baseNow - 1000});
    await setUsageEnrollment(ctx, {ownerId, mode: 'enrolled', policyPlan: 'premium',
      consentRevision: 'subset-test', requestId: `enroll_${ownerId}`});
    const bytes = png(), file = bucket.file(`users/${ownerId}/managed-images/workout/test/image`);
    await file.save(bytes, {resumable: false, metadata: {contentType: 'image/png', metadata: {sha256: hashBytes(bytes)}}});
    const [metadata] = await file.getMetadata();
    const asset = {assetId: 'image', ownerId, path: file.name, bucket: bucket.name, generation: String(metadata.generation),
      sizeBytes: bytes.length, sha256: hashBytes(bytes), contentType: 'image/png', tokenFree: true,
      source: `${ctx.mediaBaseUrl}?assetId=image&v=${metadata.generation}`};
    await db.doc(`imageUsageAccounts/${ownerId}/assets/image`).set(asset);
    const workout = {id: 'workout', ownerId, author: {id: ownerId, displayName: 'Coach'}, name: 'Class', folder: '',
      createdAt: baseNow, updatedAt: baseNow, brandL: '', brandR: '', soundVolume: 0, countdownSeconds: 0,
      modules: [{id: 'module', name: 'Work', text: '', imageUrl: asset.source, workSeconds: 10,
        restSeconds: 0, sets: 1, beep: false, coverImage: false}]};
    const call = input => handleClassAdmission({...ctx, actor, input: {schemaVersion: 1, ...input}});
    const prepared = await call({action: 'prepare', requestId: `prepare_${ownerId}`, workout,
      targetDeviceIds: ['a', 'b'], controllerDeviceId: 'controller', clientFingerprint: 'immutable-cohort-fingerprint'});
    const admissionRef = db.doc(`imageUsageAccounts/${ownerId}/admissions/${prepared.admissionId}`);
    const receipt = id => user.child(`displayPreparation/responses/${id}`).set({sessionId: prepared.sessionId,
      revision: prepared.epoch, manifestHash: prepared.manifestHash, status: 'ready', checkedAtMs: now,
      imageCount: 1, audioReady: true});
    const input = (ids = ['a'], requestId = `commit_${prepared.admissionId}`) => ({schemaVersion: 1,
      action: 'commitSelected', requestId, admissionId: prepared.admissionId, sessionId: prepared.sessionId,
      epoch: prepared.epoch, manifestHash: prepared.manifestHash, selectedTargetDeviceIds: ids,
      start: {stepIndex: 0, durationMs: 10000, briefing: false, scheduled: false, scheduledAtMs: null, updatedByDeviceId: 'controller'}});
    const commit = ids => call(input(ids));
    const mediaContext = (id, purpose = 'playback') => ({ownerId, actorUid: uid(id), purpose,
      sessionId: prepared.sessionId, admissionId: prepared.admissionId});
    const transfer = id => ({...mediaContext(id, 'preparation'), deviceId: id, leaseId: 'test-lease',
      assetId: asset.assetId, generation: asset.generation, sizeBytes: asset.sizeBytes});
    return {ctx, actor, ownerId, user, uid, asset, bytes, prepared, admissionRef, receipt, input, call, commit,
      mediaContext, transfer, setNow: value => { now = value; }};
  }
  try {
    await db.doc('appConfig/imageUsage').set({schemaVersion: 1, policyRevision: imageUsagePolicyRevision,
      enabled: true, allowedProjectIds: [projectId]});
    await t.test('failed and then removed unselected display does not veto; cohort, media and reservation stay frozen', async () => {
      const f = await fixture(); await f.receipt('a');
      await f.user.child('displayPreparation/responses/b').set({status: 'failed'});
      await f.user.child('devices/b').remove();
      const before = (await f.admissionRef.get()).data(), request = (await f.user.child('displayPreparation/request').get()).val();
      assert.equal(f.prepared.supportsTargetSubset, true);
      const started = await f.commit(['a']);
      assert.deepEqual(started.session.targetDeviceIds, ['a']);
      assert.deepEqual(started.targetDeviceIds, ['a', 'b']);
      assert.deepEqual(started.selectedTargetDeviceIds, ['a']);
      const after = (await f.admissionRef.get()).data();
      for (const key of ['manifest', 'manifestHash', 'targetDeviceIds', 'targetBindings', 'images', 'reservedDownloadBytes',
        'preparationRemainingBytes', 'preparationAllocations']) assert.deepEqual(after[key], before[key], key);
      assert.deepEqual((await f.user.child('displayPreparation/request').get()).val(), request);
      assert.deepEqual((await f.user.child('operations').get()).val(), {unchanged: 'keep'});
      assert.equal((await readUsage(f.ctx, {ownerId: f.ownerId})).downloadDay.reservedBytes, f.bytes.length * 3);
      assert.equal((await db.doc(`imageUsageAccounts/${f.ownerId}`).get()).data().activeAdmissionId, f.prepared.admissionId);
    });
    await t.test('legacy commit still requires every receipt and publishes the whole cohort', async () => {
      const f = await fixture(); await f.receipt('a');
      const {selectedTargetDeviceIds, ...old} = {...f.input(), action: 'commit'};
      await reason(f.call(old), 'session_changed');
      await f.receipt('b');
      const started = await f.call(old);
      assert.deepEqual(started.session.targetDeviceIds, ['a', 'b']);
      assert.equal((await f.admissionRef.get()).data().selectedTargetDeviceIds, undefined);
      assert.equal((await requireUsageContext(f.ctx, f.mediaContext('b'))).protected, true);
    });
    await t.test('empty, duplicates, invalid, foreign, superset and stale proof cannot publish', async () => {
      const f = await fixture(); await f.receipt('a');
      const before = (await f.admissionRef.get()).data();
      for (const ids of [[], ['a', 'a'], ['../a'], null]) await reason(f.commit(ids), 'upload_mismatch');
      for (const ids of [['foreign'], ['a', 'b', 'foreign']]) await reason(f.commit(ids), 'session_changed');
      for (const bad of [{manifestHash: 'stale'}, {sessionId: 'stale'}, {epoch: 12345}]) {
        await reason(f.call({...f.input(), ...bad}), 'session_changed');
      }
      await reason(handleClassAdmission({...f.ctx, actor: {uid: 'foreign-owner'}, input: f.input()}), 'session_changed');
      await reason(handleClassAdmission({...f.ctx, actor: {uid: f.ownerId, token: {firebase: {sign_in_provider: 'anonymous'}}}, input: f.input()}), 'media_lease_invalid');
      assert.deepEqual((await f.admissionRef.get()).data(), before);
      assert.equal((await f.user.child('activeSession').get()).exists(), false);
    });
    await t.test('selected receipt, freshness, health, binding and revocation are rechecked', async () => {
      const f = await fixture(); await f.receipt('a');
      const device = (await f.user.child('devices/a').get()).val();
      for (const bad of [{online: false}, {lastSeenAtMs: baseNow - 75000}, {lastSeenAtMs: baseNow + 5001},
        {displayState: 'standby'}, {preparationHealth: {code: 'failed', requestId: f.prepared.sessionId}}]) {
        await f.user.child('devices/a').set({...device, ...bad});
        await reason(f.commit(), 'session_changed');
      }
      await f.user.child('devices/a').set({...device, pairedAtMs: baseNow});
      await reason(f.commit(), 'session_changed');
      await f.user.child('devices/a').set({...device, paired: false});
      await reason(f.commit(), 'policy_or_client_upgrade_required');
      await f.user.child('devices/a').remove();
      await reason(f.commit(), 'policy_or_client_upgrade_required');
      await f.user.child('devices/a').set(device);
      await realtime.ref(`displayConnectionRevocations/${f.uid('a')}/123456`).set(true);
      await reason(f.commit(), 'media_lease_invalid');
      await realtime.ref(`displayConnectionRevocations/${f.uid('a')}`).remove();
      for (const bad of [{revision: 0}, {manifestHash: 'stale'}, {audioReady: false}, {imageCount: 0},
        {status: 'failed'}, {checkedAtMs: baseNow - 1}, {checkedAtMs: baseNow + 5001}]) {
        await f.receipt('a'); await f.user.child('displayPreparation/responses/a').update(bad);
        await reason(f.commit(), 'session_changed');
      }
      assert.equal((await f.user.child('activeSession').get()).exists(), false);
      await f.receipt('a');
      await f.user.child('devices/a').update({lastSeenAtMs: baseNow - 90000, currentConnectionId: 'connection',
        heartbeatPolicy: {schemaVersion: 1, revision: 1, heartbeatIntervalSeconds: 60,
          noResponseTimeoutSeconds: 180, connectionId: 'connection'}});
      assert.equal((await f.commit()).status, 'active');
    });
    await t.test('changed brand/media, expiry, entitlement, quota and active slot cannot bypass admission', async () => {
      const f = await fixture(); await f.receipt('a');
      await f.user.child('operations/brand').set({logoUrl: f.asset.source});
      await reason(f.commit(), 'session_changed');
      await f.user.child('operations/brand').remove();
      const assetRef = db.doc(`imageUsageAccounts/${f.ownerId}/assets/image`);
      await assetRef.update({generation: '0'});
      await reason(f.commit(), 'legacy_asset_transition_required');
      await assetRef.set(f.asset);
      f.setNow(f.prepared.prepareExpiresAtMs);
      await reason(f.commit(), 'admission_expired'); f.setNow(baseNow);
      const entitlementRef = db.doc(`subscriptionEntitlements/${f.ownerId}`);
      await entitlementRef.update({canStartClass: false});
      await reason(f.commit(), 'entitlement_unverified'); await entitlementRef.update({canStartClass: true});
      const accountRef = db.doc(`imageUsageAccounts/${f.ownerId}`);
      await accountRef.update({activeAdmissionId: 'another'});
      await reason(f.commit(), 'session_changed'); await accountRef.update({activeAdmissionId: f.prepared.admissionId});
      const period = db.doc(`imageUsageAccounts/${f.ownerId}/periods/downloadDay_${usagePeriods(baseNow).dayKey}`);
      await period.update({usedBytes: 1000000000});
      await reason(f.commit(), 'daily_transfer_limit');
      assert.equal((await f.admissionRef.get()).data().status, 'preparing');
      assert.equal((await f.user.child('activeSession').get()).exists(), false);
    });
    await t.test('canonical retries converge; changing selection or start cannot replace accepted publication', async () => {
      const f = await fixture(); await f.receipt('a'); await f.receipt('b');
      const first = await f.commit(['b', 'a']);
      assert.deepEqual(first.session.targetDeviceIds, ['a', 'b']);
      assert.equal((await f.commit(['a', 'b'])).session.id, first.session.id);
      await reason(f.commit(['a']), 'idempotency_conflict');
      await reason(f.call(f.input(['a'], 'different_selection')), 'idempotency_conflict');
      const changed = f.input(['a', 'b'], 'different_start'); changed.start.briefing = true;
      await reason(f.call(changed), 'idempotency_conflict');
      assert.deepEqual((await f.user.child('activeSession').get()).val().targetDeviceIds, ['a', 'b']);
    });
    await t.test('concurrent differing selections freeze exactly one selection', async () => {
      const f = await fixture(); await f.receipt('a'); await f.receipt('b');
      const results = await Promise.allSettled(['a', 'b'].map(id => f.call(f.input([id], `concurrent_${id}`))));
      assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
      assert.equal(results.find(r => r.status === 'rejected').reason.details.reason, 'idempotency_conflict');
      const winner = results.find(r => r.status === 'fulfilled').value;
      assert.deepEqual((await f.user.child('activeSession').get()).val().targetDeviceIds, winner.selectedTargetDeviceIds);
    });
    await t.test('outbox recovery keeps selected targets after publication uncertainty and expiry', async () => {
      const f = await fixture(); await f.receipt('a');
      let once = true;
      const uncertain = {...f.ctx, realtime: {ref: path => {
        const original = realtime.ref(path);
        if (path !== `users/${f.ownerId}`) return original;
        return {get: () => original.get(), transaction: async fn => {
          const result = await original.transaction(fn);
          if (once) { once = false; throw new Error('injected publication uncertainty'); }
          return result;
        }};
      }}};
      await assert.rejects(handleClassAdmission({...uncertain, actor: f.actor, input: f.input()}), /injected publication/);
      assert.equal((await f.admissionRef.get()).data().status, 'committing');
      assert.equal((await db.doc(`imageUsageAccounts/${f.ownerId}/outbox/${f.prepared.admissionId}`).get()).data().phase, 'commitSelected');
      await reason(f.call(f.input(['b'], 'changed_pending')), 'idempotency_conflict');
      const {selectedTargetDeviceIds, ...old} = {...f.input(), action: 'commit', requestId: 'old_after_selected'};
      await reason(f.call(old), 'idempotency_conflict');
      f.setNow(baseNow + 3600000);
      const recovered = await f.call({action: 'get', admissionId: f.prepared.admissionId});
      assert.equal(recovered.supportsTargetSubset, true);
      assert.deepEqual(recovered.selectedTargetDeviceIds, ['a']);
      assert.deepEqual(recovered.session.targetDeviceIds, ['a']);
      assert.equal((await f.commit()).session.id, recovered.session.id);
      assert.equal((await requireUsageContext(f.ctx, f.mediaContext('a'))).protected, true);
      await reason(requireUsageContext(f.ctx, f.mediaContext('b')), 'media_lease_invalid');
    });
    await t.test('final publication rechecks selected device and never replaces an unrelated active class', async () => {
      const f = await fixture(); await f.receipt('a');
      let once = true;
      const changed = {...f.ctx, realtime: {ref: path => {
        const original = realtime.ref(path);
        if (path !== `users/${f.ownerId}`) return original;
        return {get: () => original.get(), transaction: async fn => {
          if (once) { once = false; await f.user.child('devices/a/paired').set(false); }
          return original.transaction(fn);
        }};
      }}};
      await reason(handleClassAdmission({...changed, actor: f.actor, input: f.input()}), 'usage_reconciliation_pending');
      assert.equal((await f.user.child('activeSession').get()).exists(), false);
      await f.user.child('devices/a/paired').set(true);
      await f.user.child('activeSession').set({id: 'ongoing', status: 'paused'});
      await reason(f.call({action: 'get', admissionId: f.prepared.admissionId}), 'usage_reconciliation_pending');
      assert.deepEqual((await f.user.child('activeSession').get()).val(), {id: 'ongoing', status: 'paused'});
    });
    await t.test('excluded preparation leases fail issue, HEAD and GET after commit; selected media still works', async () => {
      const f = await fixture(); await f.receipt('a');
      const issueInput = {schemaVersion: 1, action: 'issue', requestId: 'before_selection', assetIds: ['image'],
        admissionId: f.prepared.admissionId, sessionId: f.prepared.sessionId, purpose: 'preparation'};
      const oldLease = await handleMediaLease(f.ctx, issueInput, f.uid('b'));
      await f.commit();
      await reason(handleMediaLease(f.ctx, issueInput, f.uid('b')), 'media_lease_invalid');
      await reason(reserveTransfer(f.ctx, f.transfer('b')), 'media_lease_invalid');
      const selectedLease = await handleMediaLease(f.ctx, {...issueInput, requestId: 'selected_playback', purpose: 'playback'}, f.uid('a'));
      await serve(handleMedia, f.ctx, async origin => {
        const url = `${origin}/?assetId=image&v=${f.asset.generation}`;
        const headers = (id, leaseId) => ({Authorization: `Bearer ${f.uid(id)}`, 'X-CloudBoard-Media-Lease': leaseId});
        for (const method of ['HEAD', 'GET']) {
          const denied = await fetch(url, {method, headers: headers('b', oldLease.leaseId)});
          assert.equal(denied.status, 403); await denied.arrayBuffer();
        }
        const served = await fetch(url, {headers: headers('a', selectedLease.leaseId)});
        const body = Buffer.from(await served.arrayBuffer());
        assert.equal(served.status, 200, body.toString());
        assert.deepEqual(body, f.bytes);
      });
      const usage = await readUsage(f.ctx, {ownerId: f.ownerId});
      assert.equal(usage.downloadDay.usedBytes, f.bytes.length);
    });
    await t.test('transfer transaction cannot spend a stale pre-selection authorization', async () => {
      const f = await fixture(); await f.receipt('a');
      let once = true;
      const racing = {...f.ctx, db: {doc: db.doc.bind(db), getAll: db.getAll.bind(db), runTransaction: async fn => {
        if (once) { once = false; await f.commit(); }
        return db.runTransaction(fn);
      }}};
      await reason(reserveTransfer(racing, f.transfer('b')), 'media_lease_invalid');
      assert.equal((await readUsage(f.ctx, {ownerId: f.ownerId})).downloadDay.reservedBytes, f.bytes.length * 3);
    });
  } finally { await deleteApp(app); }
});
