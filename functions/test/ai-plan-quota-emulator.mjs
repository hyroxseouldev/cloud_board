import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {handleAiSlides} from '../src/ai-slides.js';
import {handleAiSlideDesigns} from '../src/ai-slide-designs.js';
import {handleAiTimer, AI_TIMER_BUDGET, AI_TIMER_GLOBAL_LIMIT} from '../src/ai-timer.js';

// Only emulator transactions and injected providers; no credentials or paid calls.
assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):\d+$/);
const projectId = 'demo-cloudboard-ai-plans';
const app = initializeApp({projectId}), db = getFirestore(app);
const now = Date.parse('2026-10-15T00:00:00Z');
let calls = 0;
const grant = (uid, plan, extra = {}) => db.doc(`subscriptionEntitlements/${uid}`).set({
  plan, policyVersion: 'plan-entitlements-v2', status: 'active', validUntilMs: now + 90 * 86400000, ...extra,
});
const usage = (uid, month = '2026-10', feature = 'aiSlides') => db.doc(`users/${uid}/${feature}Usage/${month}`);
const content = prompt => ({complete: true, slides: [{title: 'WORKOUT', layout: 'list', sourceTitleLineIds: [],
  sections: [{heading: '', lines: [prompt], sourceLineIds: [1]}], workSeconds: null, restSeconds: null, sets: null}], warnings: []});
const recognize = async source => { calls++; return {result: content(source.prompt), costMicros: 100}; };
const options = (uid, extra = {}) => ({db, uid, now, apiKey: 'test-only-injected-provider',
  input: {action: 'generate', prompt: 'Run 1km'}, recognize, ...extra});
const slide = (uid, extra) => handleAiSlides(options(uid, extra));
const status = uid => slide(uid, {input: {action: 'status'}});
const reason = expected => error => error.details?.reason === expected;
const style = family => ({name: family, description: 'Readable style', family,
  backgroundColor: 0xFFFFFFFF, textColor: 0xFF121212, accentColor: 0xFF3355BB,
  titleColor: family === 'banner' ? 0xFFFFFFFF : 0xFF121212, fontFamily: 'sans',
  titleWeight: 700, bodyWeight: 600, italic: false, spacing: 1, motif: ''});
const design = (uid, extra = {}) => handleAiSlideDesigns(options(uid, {
  recognize: async () => { calls++; return {result: {designs: ['banner', 'focus', 'editorial'].map(style), warnings: []}, costMicros: 100}; }, ...extra,
}));
const png = Buffer.alloc(24); Buffer.from([137,80,78,71,13,10,26,10]).copy(png);
png.write('IHDR', 12); png.writeUInt32BE(100, 16); png.writeUInt32BE(100, 20);
const timer = (uid, extra = {}) => handleAiTimer(options(uid, {input: {action: 'analyze', imageBase64: png.toString('base64')},
  recognize: async () => {calls++; return {result: {multipleTimers: false, workSeconds: 30, restSeconds: 10, sets: 4, name: null, warnings: []}, costMicros: 100};}, ...extra}));

try {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {method: 'DELETE'});
  await grant('old-plus', 'plus', {policyVersion: 'plan-entitlements-v1'});
  await assert.rejects(slide('old-plus'), reason('plan-required'));
  await grant('free', 'free');
  assert.equal((await status('free')).allowed, false);
  await assert.rejects(slide('free'), reason('plan-required'));
  await assert.rejects(status('missing'), reason('entitlement-unavailable'));
  for (const [uid, extra] of [['expired', {validUntilMs: now}], ['refund', {status: 'revoked'}]]) {
    await grant(uid, 'premium', extra);
    await assert.rejects(slide(uid), reason('entitlement-unavailable'));
  }
  await assert.rejects(slide('lookup-error', {db: {
    doc: path => db.doc(path),
    runTransaction: async () => {throw new HttpsError('unavailable', 'permission lookup unavailable');},
  }}), {code: 'unavailable'});
  assert.equal((await usage('lookup-error').get()).exists, false);
  assert.equal(calls, 0, 'denied and unavailable grants never contact a provider');
  for (const [plan, limit] of [['plus', 10], ['premium', 30]]) {
    await grant(plan, plan);
    await usage(plan).set({used: limit - 1, attempts: limit - 1});
    const last = await slide(plan);
    assert.equal(last.used, limit); assert.equal(last.remaining, 0);
    assert.equal(last.allowed, true); assert.equal(last.premium, plan === 'premium');
    const callsAtLimit = calls;
    assert.equal((await slide(plan)).cached, true);
    assert.equal(calls, callsAtLimit);
    await assert.rejects(slide(plan, {now: now + 6000, input: {action: 'generate', prompt: 'Row 500m'}}), error => {
      assert.equal(error.details.used, limit); assert.equal(error.details.limit, limit);
      assert.equal(error.details.resetsAtMs, Date.parse('2026-10-31T15:00:00Z'));
      return reason('user-limit')(error);
    });
  }
  await grant('trial', 'premium', {status: 'trialing'});
  assert.equal((await status('trial')).limit, 30);
  assert.equal((await timer('trial', {input: {action: 'status'}})).limit, 100);
  await assert.rejects(timer('plus'), reason('premium-required'));
  await grant('shared', 'plus');
  await slide('shared');
  assert.equal((await design('shared', {now: now + 6000})).used, 2);
  assert.equal((await usage('shared').get()).data().used, 2);
  await grant('shared', 'premium');
  assert.equal((await timer('shared')).used, 1);
  assert.equal((await usage('shared').get()).data().used, 2, 'timer is a separate counter');
  await usage('shared', '2026-10', 'aiTimer').update({used: 99});
  const changedImage = {...options('shared').input, action: 'analyze', imageBase64: Buffer.concat([png, Buffer.from([1])]).toString('base64')};
  assert.equal((await timer('shared', {now: now + 12000, input: changedImage})).used, 100);
  await assert.rejects(timer('shared', {now: now + 18000, input: {...changedImage, imageBase64: Buffer.concat([png, Buffer.from([2])]).toString('base64')}}), reason('user-limit'));
  await grant('changes', 'plus'); await usage('changes').set({used: 8});
  await grant('changes', 'premium'); assert.equal((await status('changes')).remaining, 22);
  await usage('changes').set({used: 15}); await grant('changes', 'plus');
  assert.equal((await status('changes')).remaining, 0); assert.equal((await status('changes')).used, 15);
  await grant('changes', 'premium'); assert.equal((await status('changes')).remaining, 15, 'repurchase never clears usage');
  await grant('race', 'plus'); await usage('race').set({used: 9, attempts: 9});
  const beforeRace = calls;
  const race = await Promise.allSettled([slide('race'), design('race')]);
  assert.equal(race.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(calls - beforeRace, 1); assert.equal((await usage('race').get()).data().used, 10);
  await grant('failure', 'plus');
  await assert.rejects(slide('failure', {recognize: async () => {throw new HttpsError('unavailable', 'safe', {reason: 'provider-429'});}}), reason('provider-429'));
  assert.equal((await usage('failure').get()).data().used, 0);
  await assert.rejects(slide('failure'), reason('cooldown'));
  assert.equal((await slide('failure', {now: now + 61000})).used, 1);
  await grant('month', 'plus'); await usage('month').set({used: 10});
  assert.equal((await slide('month', {now: Date.parse('2026-10-31T14:59:59Z'), input: {action: 'status'}})).remaining, 0);
  const freshMonth = await slide('month', {now: Date.parse('2026-10-31T15:00:00Z')});
  assert.equal(freshMonth.used, 1); assert.equal((await usage('month').get()).data().used, 10);
  assert.equal((await usage('month', '2026-11').get()).data().used, 1);
  await grant('stopped', 'plus');
  await assert.rejects(slide('stopped', {apiKey: ''}), reason('not-configured'));
  await db.doc('appConfig/aiSlides').set({enabled: false});
  assert.equal((await status('stopped')).availabilityReason, 'feature-disabled');
  await assert.rejects(slide('stopped'), reason('feature-disabled'));
  await db.doc('appConfig/aiSlides').delete();
  for (const budget of [{spentMicros: AI_TIMER_BUDGET, calls: 0}, {spentMicros: 0, calls: AI_TIMER_GLOBAL_LIMIT}]) {
    await db.doc('aiTimerBudgets/2026-10').set(budget);
    assert.equal((await status('stopped')).availabilityReason, 'service-limit');
    await assert.rejects(slide('stopped'), reason('service-limit'));
  }
  assert.equal((await usage('stopped').get()).exists, false);
  const metrics = (await db.doc('aiRequestMetrics/2026-10').get()).data();
  assert.equal(metrics.content.provider_failed, 1);
  assert.equal(metrics.content.quota_refunded, 1);
  assert.equal(metrics.content.service_limit, 2);
  assert.equal(metrics.content.not_configured, 1);
  assert.equal(metrics.content.feature_disabled, 1);
  assert(metrics.content.user_limit >= 2); assert(metrics.design.completed >= 1);
  assert(!JSON.stringify(metrics).includes('test-only'));
  console.log('PASS STA157: Plus10/Premium30 shared content-design, separate timer100, trial/denials, upgrade/downgrade/repurchase, concurrent last-slot, cache, refund/retry, KST reset, cost/call/feature/provider metrics');
} finally {await deleteApp(app);}
