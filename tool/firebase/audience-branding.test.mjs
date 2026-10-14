import test from 'node:test';
import assert from 'node:assert/strict';
import {audienceReadiness, validateSupportMatrix, parseArguments, reconcileAudienceOwners} from './audience-branding.mjs';
import {audienceLogoVersion} from '../../functions/src/standby-branding.js';
import {planAccess} from '../../functions/src/plan-policy.js';
const now = 10000;
const support = {audienceLogoVersion, platforms: {android: {minimumBuild: 80, publishedBuild: 82, evidenceUrl: 'https://example.org/release/82'}}};
const ready = () => ({ownerId: 'owner', entitlement: {...planAccess('free'), plan: 'free', status: 'active', validUntilMs: now + 10000},
  rollout: {version: audienceLogoVersion, enabled: true, ownerIds: ['owner']},
  releases: {android: {enabled: true, published: true, minimumBuild: 80, latestBuild: 82, publishedBuild: 82}},
  devices: {tv: {paired: true, appPlatform: 'android', appBuild: '80', online: true, lastSeenAtMs: now}},
  projection: {projectionRevision: 4}});

test('readiness requires supported paired clients and published minimum build evidence, not quota/playback protocol guesses', () => {
  assert.equal(audienceReadiness(ready(), support, now).readyForAllAudience, true);
  for (const patch of [{appBuild: '79'}, {appBuild: ''}, {appBuild: '999'}, {appPlatform: 'unknown'}]) {
    const state = ready(); Object.assign(state.devices.tv, patch);
    assert.equal(audienceReadiness(state, support, now).readyToApply, false);
  }
  const release = ready(); release.releases.android.published = false;
  assert.equal(audienceReadiness(release, support, now).readyForAllAudience, false);
  const minimum = ready(); minimum.releases.android.minimumBuild = 79;
  assert.equal(audienceReadiness(minimum, support, now).readyForAllAudience, false);
  const unpaired = ready(); unpaired.devices.old = {paired: false, appBuild: '1'};
  assert.equal(audienceReadiness(unpaired, support, now).readyForAllAudience, true);
  const legacyPair = ready(); legacyPair.devices.old = {pairedAtMs: 1, appBuild: '1'};
  assert.equal(audienceReadiness(legacyPair, support, now).readyForAllAudience, false);
  const offline = ready(); offline.devices.tv.online = false; offline.activeSession = {status: 'playing'};
  const report = audienceReadiness(offline, support, now);
  assert.equal(report.readyForAllAudience, true);
  assert.deepEqual(report.warnings, ['device-offline-or-stale:tv', 'ongoing-class-not-interrupted']);
});

test('v1, missing/expired entitlement and deletion cannot be activated; inactive scope can be reconciled without rejecting old clients', () => {
  for (const patch of [{entitlement: null}, {deleted: true}, {entitlement: {...ready().entitlement, validUntilMs: now}},
    {entitlement: {...ready().entitlement, policyVersion: 'plan-entitlements-v1'}}]) {
    assert.equal(audienceReadiness({...ready(), ...patch}, support, now).readyToApply, false);
  }
  const state = ready(); state.rollout.enabled = false; state.devices.tv.appBuild = '1';
  const report = audienceReadiness(state, support, now);
  assert.equal(report.readyForAllAudience, false);
  assert.equal(report.readyToApply, true);
  assert.equal(report.expectedScope, 'standby');
});

test('web Hosting run.attempt build IDs require exact published evidence, never numeric coercion', () => {
  const webSupport = {audienceLogoVersion, platforms: {web: {allowedBuilds: ['542.1', '542.2'], evidenceUrl: 'https://example.org/hosting/542'}}};
  const state = ready(); state.devices.tv = {paired: true, appPlatform: 'web', appBuild: '542.1', online: true, lastSeenAtMs: now};
  const report = audienceReadiness(state, webSupport, now);
  assert.equal(report.readyForAllAudience, true);
  assert.equal(report.devices[0].build, '542.1');
  for (const build of ['542.3', '543.1', '542', 542.1, '', undefined]) {
    state.devices.tv.appBuild = build;
    assert.equal(audienceReadiness(state, webSupport, now).readyToApply, false);
  }
  assert.throws(() => validateSupportMatrix({audienceLogoVersion, platforms: {web: support.platforms.android}}), /exact/);
  assert.throws(() => validateSupportMatrix({audienceLogoVersion, platforms: {web: {allowedBuilds: ['542.1', '542.1'], evidenceUrl: 'https://example.org'}}}), /exact/);
});

test('read-only never projects; explicit apply rechecks state and confirms monotonic server-owned payload', async () => {
  let writes = 0, loads = 0;
  const state = ready();
  const load = async () => {loads++; return state;};
  const project = async () => {writes++; state.projection = {ownerId: 'owner', projectionRevision: 5, audienceLogoVersion,
    audienceLogoScope: 'all-audience', showCloudBoardLogo: true}; return true;};
  const args = {owners: ['owner'], support, load, project, now: () => now};
  const dry = await reconcileAudienceOwners(args);
  assert.equal(dry.mode, 'read-only'); assert.equal(writes, 0); assert.equal(loads, 1);
  const applied = await reconcileAudienceOwners({...args, apply: true});
  assert.equal(writes, 1); assert.equal(loads, 4); assert.equal(applied.reports[0].applied, true);
  const failed = await reconcileAudienceOwners({...args, project: async () => false, apply: true});
  assert.equal(failed.reports[0].applyError, 'projection-not-confirmed');
  let first = true;
  const changed = await reconcileAudienceOwners({...args, apply: true, load: async () => {
    if (first) {first = false; return ready();} return {...ready(), deleted: true};
  }});
  assert.equal(changed.reports[0].applied, false); assert.equal(writes, 1);
});

test('CLI requires explicit target, support evidence, selected owners and an extra apply confirmation', () => {
  const args = ['--project', 'demo-branding', '--database-url', 'https://demo-branding-default-rtdb.asia-southeast1.firebasedatabase.app',
    '--owner', 'owner', '--support', '/tmp/support.json'];
  assert.equal(parseArguments(args).apply, false);
  assert.throws(() => parseArguments([...args, '--apply']), /confirm-project/);
  assert.equal(parseArguments([...args, '--apply', '--confirm-project', 'demo-branding']).apply, true);
  assert.throws(() => parseArguments([...args, '--owner', 'owner']), /distinct/);
  assert.throws(() => parseArguments([...args, '--owner', 'wrong/path']), /owner/);
  assert.throws(() => parseArguments([...args, '--database-url', 'https://other-default-rtdb.firebaseio.com']), /match/);
  for (const value of [{}, {...support, audienceLogoVersion: 'future'}, {audienceLogoVersion, platforms: {}},
    {audienceLogoVersion, platforms: {android: {minimumBuild: 80, publishedBuild: 79, evidenceUrl: 'https://example.org'}}},
    {audienceLogoVersion, platforms: {android: {minimumBuild: 80, publishedBuild: 80}}}]) {
    assert.throws(() => validateSupportMatrix(value));
  }
});
