import test from 'node:test';
import assert from 'node:assert/strict';
import {HttpsError} from 'firebase-functions/v2/https';
import {handleSlideStudio, studioTokenUsage} from '../src/slide-studio.js';
import {aiTimerMonth} from '../src/ai-timer.js';

// In-memory transactional contract double. No emulator/provider/network used.
class MemoryDb {
  constructor() { this.rows = new Map(); this.queue = Promise.resolve(); }
  doc(path) {
    return {path, collection: name => ({doc: id => this.doc(`${path}/${name}/${id}`)}),
      get: async () => this.snapshot(path),
      set: async (value, options) => this.write(path, value, options)};
  }
  snapshot(path) { const value = this.rows.get(path); return {exists: value !== undefined, data: () => value}; }
  async getAll(...refs) { return refs.map(ref => this.snapshot(ref.path)); }
  write(path, value, options) { this.rows.set(path, options?.merge ? {...this.rows.get(path), ...value} : value); }
  runTransaction(callback) {
    const run = this.queue.then(async () => {
      const writes = [];
      const result = await callback({getAll: (...refs) => this.getAll(...refs),
        get: async ref => this.snapshot(ref.path),
        set: (ref, value, options) => writes.push([ref.path, value, options])});
      for (const args of writes) this.write(...args);
      return result;
    });
    this.queue = run.catch(() => {});
    return run;
  }
}
const now = Date.parse('2026-10-20T16:00:00Z');
const uid = 'studio-preview', centerId = 'studio-preview-center';
const rawWod = 'Row 1,000 m\nDB Squat 22.5 kg × 12\n휴식 60초';
const input = {action: 'generate', operation: 'organize', requestId: 'test-operation-1', centerId, rawWod, brief: ''};
function setup() {
  const db = new MemoryDb();
  db.rows.set(`users/${uid}/onboarding/progress`, {storeId: centerId});
  db.rows.set(`centers/${centerId}`, {ownerUid: uid});
  db.rows.set(`subscriptionEntitlements/${uid}`, {plan: 'plus', policyVersion: 'plan-entitlements-v2',
    status: 'active', validUntilMs: now + 86400000});
  const options = {db, uid, apiKey: 'test-only-not-a-key', clock: () => now};
  let calls = 0;
  const organize = async source => {
    calls++;
    return {result: {groups: [{heading: 'A', lines: source.lines}]}, costMicros: 10,
      usage: {input: 27, output: 9}};
  };
  return {db, options: {...options, organize}, calls: () => calls};
}
const usagePath = `users/${uid}/aiSlidesUsage/${aiTimerMonth(now).id}`;

test('usage reflects existing request policy and never converts requests or budget to token allowance', async () => {
  const {db, options} = setup();
  db.rows.set(usagePath, {used: 3});
  const result = await handleSlideStudio({...options, input: {action: 'usage', centerId}});
  assert.equal(result.remaining, 7); assert.equal(result.limit, 10);
  assert.deepEqual(result.tokenAllowance, {kind: 'not-metered', remaining: null, limit: null});
  assert.equal(result.lastOperationTokens, null);
  db.rows.set(usagePath, {used: 'unknown'});
  await assert.rejects(handleSlideStudio({...options, input: {action: 'usage', centerId}}), {code: 'failed-precondition'});
});

test('one explicit request preserves source, reports actual tokens, and retries never charge again', async () => {
  const {db, options, calls} = setup();
  const result = await handleSlideStudio({...options, input});
  assert.deepEqual(result.job.result.groups.flatMap(g => g.lines), rawWod.split('\n'));
  assert.equal(result.job.status, 'completed');
  assert.deepEqual(result.job.usage, {input: 27, output: 9, total: 36});
  for (let i = 0; i < 3; i++) await handleSlideStudio({...options, input});
  assert.equal(calls(), 1); assert.equal(db.rows.get(usagePath).used, 1);
  const usage = await handleSlideStudio({...options, input: {action: 'usage', centerId, requestId: input.requestId}});
  assert.equal(usage.lastOperationTokens.total, 36);
  await assert.rejects(handleSlideStudio({...options, input: {...input, rawWod: 'different 20kg'}}), {code: 'already-exists'});
  assert.equal(calls(), 1);
});

test('concurrent clicks and stale processing requests do not reclaim a provider operation', async () => {
  const {options, db} = setup();
  let resolve, started;
  const didStart = new Promise(r => { started = r; });
  let calls = 0;
  const organize = async source => { calls++; started(); return new Promise(r => {
    resolve = () => r({result: {groups: [{heading: 'A', lines: source.lines}]}, costMicros: 1});
  }); };
  const pending = handleSlideStudio({...options, input, organize});
  await didStart;
  const duplicate = await handleSlideStudio({...options, input, organize});
  assert.equal(duplicate.job.status, 'processing');
  const stale = await handleSlideStudio({...options, input, organize, clock: () => now + 120000});
  assert.equal(stale.job.status, 'uncertain');
  assert.equal(calls, 1); assert.equal(db.rows.get(usagePath).used, 1);
  resolve(); await pending;
});

test('slash boundaries are unambiguous: changed same ID rejects and different IDs retain their own source', async () => {
  const {options, db, calls} = setup();
  const first = {...input, rawWod: 'Row 100m/Run 200m', brief: 'small'};
  const second = {...input, rawWod: 'Row 100m', brief: 'Run 200m/small'};
  const a = await handleSlideStudio({...options, input: first});
  await assert.rejects(handleSlideStudio({...options, input: second}), {code: 'already-exists'});
  const b = await handleSlideStudio({...options, clock: () => now + 6000,
    input: {...second, requestId: 'test-operation-2'}});
  assert.deepEqual(a.job.result.groups[0].lines, ['Row 100m/Run 200m']);
  assert.deepEqual(b.job.result.groups[0].lines, ['Row 100m']);
  assert.equal(calls(), 2); assert.equal(db.rows.get(usagePath).used, 2);
  const jobs = [...db.rows.entries()].filter(([path]) => path.includes('/slideStudioCenters/') && path.includes('/operations/'));
  assert.notEqual(jobs[0][1].hash, jobs[1][1].hash);
});

test('style metered cache is center isolated while preserving the real selected design brief', async () => {
  const {options, db} = setup();
  let calls = 0;
  const prompt = '선택 디자인 UNBROKEN · orange header, italic title';
  const design = async source => {
    calls++; assert.equal(source.prompt, prompt);
    return {costMicros: 1, usage: {input: 3, output: 1}, result: {warnings: [], designs:
      ['banner', 'focus', 'cards'].map(family => ({name: family, description: '선택 배치',
        family, backgroundColor: 0xffffffff, textColor: 0xff000000, accentColor: 0xffeeeeee,
        titleColor: 0xff000000, fontFamily: 'sans', titleWeight: 700, bodyWeight: 600,
        italic: false, spacing: 1, motif: ''}))}};
  };
  await handleSlideStudio({...options, design, input: {action: 'generate', operation: 'style', requestId: 'style-1', centerId, prompt}});
  db.rows.set(`users/${uid}/onboarding/progress`, {storeId: 'center-b'});
  db.rows.set('centers/center-b', {ownerUid: uid});
  await handleSlideStudio({...options, design, clock: () => now + 6000,
    input: {action: 'generate', operation: 'style', requestId: 'style-2', centerId: 'center-b', prompt}});
  assert.equal(calls, 2); assert.equal(db.rows.get(usagePath).used, 2);
});

test('provider failure keeps request identity, unknown tokens, old quota refund semantics and no auto-retry', async () => {
  const {options, db} = setup();
  let calls = 0;
  const organize = async () => { calls++; throw new HttpsError('unavailable', 'provider unavailable'); };
  const failed = await handleSlideStudio({...options, input, organize});
  assert.equal(failed.job.status, 'uncertain');
  assert.equal(failed.job.usage, null);
  assert.equal(db.rows.get(usagePath).used, 0);
  await handleSlideStudio({...options, input, organize, clock: () => now + 1000000});
  const checked = await handleSlideStudio({...options, input: {action: 'status', centerId, requestId: input.requestId}});
  assert.equal(checked.job.status, 'uncertain'); assert.equal(calls, 1);
});

test('signed out, other center, removed owner and deletion lock fail before generation', async () => {
  for (const kind of ['signed-out', 'center', 'owner', 'deletion']) {
    const {options, db, calls} = setup();
    if (kind === 'owner') db.rows.set(`centers/${centerId}`, {ownerUid: 'another'});
    if (kind === 'deletion') db.rows.set(`accountDeletions/${uid}`, {started: true});
    await assert.rejects(handleSlideStudio({...options, uid: kind === 'signed-out' ? null : uid,
      input: {...input, centerId: kind === 'center' ? 'foreign-center' : centerId}}));
    assert.equal(calls(), 0); assert.equal(db.rows.has(usagePath), false);
  }
});

test('fresh entitlement is required even for completed operation status and same-ID retries', async () => {
  const {options, db, calls} = setup();
  await handleSlideStudio({...options, input});
  db.rows.set(`subscriptionEntitlements/${uid}`, {plan: 'plus', status: 'revoked', validUntilMs: now + 100000});
  await assert.rejects(handleSlideStudio({...options, input}), {code: 'failed-precondition'});
  assert.equal(calls(), 1);
});

test('image provider usage is optional, account/center isolated and never claims missing tokens', async () => {
  const {options, db} = setup();
  const path = `users/${uid}/aiSlideRasterCenters/${centerId}/jobs/image-1`;
  const request = {action: 'usage', kind: 'raster', centerId, requestId: 'image-1'};
  db.rows.set(path, {status: 'completed', usage: {textInput: 11, imageInput: 80, imageOutput: 120}});
  let result = await handleSlideStudio({...options, input: request});
  assert.deepEqual(result.lastOperationTokens, {requestId: 'image-1', kind: 'image', input: 91, output: 120, total: 211});
  db.rows.set(path, {status: 'completed', usage: null});
  result = await handleSlideStudio({...options, input: request});
  assert.equal(result.lastOperationTokens, null);
  assert.equal(studioTokenUsage({input: -1, output: 2}), null);
  assert.equal(studioTokenUsage({input: 1.5, output: 2}), null);
  assert.equal(studioTokenUsage({input: Number.MAX_SAFE_INTEGER, output: 2}), null);
});
