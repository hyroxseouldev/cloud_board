import test from 'node:test';
import assert from 'node:assert/strict';
import {audienceBrandingEnabled, audienceBrandingPublicReady, audienceLogoVersion,
  applyBrandEntitlement, defaultStandbyBrand, projectStandbyBranding, saveBrandConfig} from '../src/standby-branding.js';
import {planAccess} from '../src/plan-policy.js';

const now = 10000, uid = 'owner';
const gate = {version: audienceLogoVersion, enabled: true, ownerIds: [uid]};
const access = (plan, extra = {}) => ({...planAccess(plan), plan, status: 'active', validUntilMs: now + 10000, revision: 3, ...extra});
const custom = {...defaultStandbyBrand, storeName: 'Saved center', logoUrl: 'https://example.org/logo.png',
  promotionImageUrls: ['https://example.org/fullscreen.png'], standbyFullscreen: true, standbyShowText: false, showCloudBoardLogo: false};
function fixture(entitlement = access('plus'), rollout = gate, initial = {brand: custom}) {
  let operations = structuredClone(initial);
  const values = {'subscriptionEntitlements/owner': entitlement, 'appConfig/audienceBranding': rollout};
  const snapshot = path => ({exists: values[path] != null, data: () => values[path]});
  const db = {doc: path => ({path, get: async () => snapshot(path)}), getAll: async (...refs) => refs.map(r => snapshot(r.path))};
  const realtime = {ref: path => ({transaction: async update => {
    const next = update(operations); if (next !== undefined) operations = next;
    return {committed: next !== undefined};
  }, set: async value => {operations[path.split('/').at(-1)] = value;}, remove: async () => {operations = null;}})};
  return {db, realtime, values, read: () => operations};
}

test('activation is exact, per-owner, and public only after explicit global rollout', () => {
  assert.equal(audienceBrandingEnabled(gate, uid), true);
  assert.equal(audienceBrandingEnabled(gate, 'other'), false);
  assert.equal(audienceBrandingPublicReady(gate), false);
  assert.equal(audienceBrandingPublicReady({...gate, allAccounts: true}), true);
  for (const invalid of [null, {}, {...gate, enabled: 'true'}, {...gate, enabled: false},
    {...gate, version: 'future'}, {...gate, ownerIds: uid}, {...gate, ownerIds: [], allAccounts: 'true'}]) {
    assert.equal(audienceBrandingEnabled(invalid, uid), false);
    assert.equal(audienceBrandingPublicReady(invalid), false);
  }
});

test('atomic audience contract forces Free logo independently of custom content and preserves originals', async () => {
  const f = fixture(access('free'));
  await projectStandbyBranding(f.db, f.realtime, uid, now);
  assert.deepEqual(f.read().brandConfig, custom);
  assert.deepEqual(f.read().brand, defaultStandbyBrand);
  assert.deepEqual(f.read().brandProjection, {ownerId: uid, revision: 3, projectionRevision: 1, policyVersion: 'plan-entitlements-v2',
    plan: 'free', appliedAtMs: now, validUntilMs: now + 10000, audienceLogoVersion,
    audienceLogoScope: 'all-audience', showCloudBoardLogo: true});
  f.values['subscriptionEntitlements/owner'] = access('plus', {revision: 4});
  await projectStandbyBranding(f.db, f.realtime, uid, now + 1);
  assert.deepEqual(f.read().brand, custom);
  assert.equal(f.read().brandProjection.showCloudBoardLogo, false);
  assert.equal(f.read().brandProjection.audienceLogoScope, 'all-audience');
});

test('Plus, Premium and existing trial support both preferences and same-revision settings changes', async () => {
  for (const entitlement of [access('plus'), access('premium'), access('premium', {status: 'trialing'})]) {
    const f = fixture(entitlement);
    await saveBrandConfig(f.db, f.realtime, {auth: {uid}, data: {brand: custom}}, now);
    assert.equal(f.read().brandProjection.showCloudBoardLogo, false);
    await saveBrandConfig(f.db, f.realtime, {auth: {uid}, data: {brand: {...custom, showCloudBoardLogo: true}}}, now + 1);
    assert.equal(f.read().brandProjection.showCloudBoardLogo, true);
    assert.equal(f.read().brandProjection.revision, entitlement.revision);
    assert.equal(f.read().brandProjection.projectionRevision, 2);
  }
});

test('gate-off and allowlist exclusion keep standby scope; turning off changes scope without changing the saved preference', async () => {
  for (const rollout of [undefined, {...gate, enabled: false}, {...gate, ownerIds: ['other']}, {...gate, version: 'future'}]) {
    const f = fixture(access('plus'), rollout ?? null);
    await projectStandbyBranding(f.db, f.realtime, uid, now);
    assert.equal(f.read().brandProjection.audienceLogoScope, 'standby');
    assert.equal(f.read().brandProjection.showCloudBoardLogo, false);
  }
  const f = fixture();
  await projectStandbyBranding(f.db, f.realtime, uid, now);
  f.values['appConfig/audienceBranding'] = {...gate, enabled: false};
  await projectStandbyBranding(f.db, f.realtime, uid, now + 1);
  assert.equal(f.read().brandProjection.audienceLogoScope, 'standby');
  assert.deepEqual(f.read().brandConfig, custom);
});

test('v1 Plus never migrates implicitly or loses a saved hidden logo', async () => {
  const f = fixture(access('plus', {policyVersion: 'plan-entitlements-v1'}));
  assert.equal(await projectStandbyBranding(f.db, f.realtime, uid, now), false);
  assert.deepEqual(f.read(), {brand: custom});
  await saveBrandConfig(f.db, f.realtime, {auth: {uid}, data: {brand: custom}}, now);
  assert.deepEqual(f.read(), {brand: custom});
});

test('explicit legacy capabilities and recognized pilots survive; missing capability and unknown states preserve the last projection', async () => {
  const legacy = access('plus', {plan: 'legacy', status: 'legacy', idleScreenCustomization: 'legacy',
    canUseCenterLogo: true, canHideCloudBoardLogo: true, maxActiveDisplays: 2});
  for (const entitlement of [legacy, {...legacy, plan: 'cloudboard_pro'}, access('plus', {source: 'pilot', status: 'pilot'}),
    access('premium', {source: 'firebase_billing', grantSource: 'pilot', status: 'pilot'})]) {
    const f = fixture(entitlement);
    assert.equal(await projectStandbyBranding(f.db, f.realtime, uid, now), true);
    assert.deepEqual(f.read().brand, custom);
    assert.equal(f.read().brandProjection.showCloudBoardLogo, false);
  }
  const f = fixture();
  await projectStandbyBranding(f.db, f.realtime, uid, now);
  const confirmed = structuredClone(f.read());
  for (const entitlement of [null, access('free', {status: 'unknown'}), access('free', {status: 'pilot', source: 'pilot'}),
    access('plus', {status: 'pilot', source: 'unrecognized'}), access('free', {validUntilMs: now}),
    {...legacy, canHideCloudBoardLogo: undefined}, access('free', {revision: 2})]) {
    f.values['subscriptionEntitlements/owner'] = entitlement;
    assert.equal(await projectStandbyBranding(f.db, f.realtime, uid, now), false);
    assert.deepEqual(f.read(), confirmed);
  }
});

test('Free hidden preference is denied and deletion never publishes a new audience policy', async () => {
  const f = fixture(access('free'));
  await assert.rejects(saveBrandConfig(f.db, f.realtime, {auth: {uid}, data: {brand: custom}}, now), {code: 'permission-denied'});
  f.values['accountDeletions/owner'] = {status: 'pending'};
  assert.equal(await projectStandbyBranding(f.db, f.realtime, uid, now), false);
  assert.deepEqual(f.read(), {brand: custom});
  assert.throws(() => applyBrandEntitlement(custom, access('plus', {plan: 'unknown'}), now), {code: 'failed-precondition'});
});
