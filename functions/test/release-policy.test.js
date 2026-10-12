import test from 'node:test';
import assert from 'node:assert/strict';
import {applyReleasePolicy, policyHash, validateReleasePolicy, validateAvailability} from '../tools/release-policy.mjs';
const policy = {enabled: true, published: true, latestBuild: 65, minimumBuild: 50, publishedBuild: 65,
  version: '1.0.0', message: '안정성 개선', storeUrl: 'https://play.google.com/store/apps/details?id=com.sunmkim.cloudboard'};
const now = '2026-10-12T00:00:00.000Z';
const evidence = {platform: 'tv', build: 65, version: '1.0.0', storeUrl: policy.storeUrl, installable: true,
  track: 'production', sourceSha: 'a'.repeat(40), countries: ['KR'], deviceVerification: 'Android TV 14 Play Store installation verified',
  verifiedBy: 'operator', verifiedAt: now, verificationUrl: policy.storeUrl};
function database(initial) {
  let current = initial; const history = [];
  return {doc: path => path, history, current: () => current, async runTransaction(run) {
    const writes = []; const result = await run({get: async () => ({exists: current != null, data: () => current}),
      create: (path, value) => writes.push(() => history.push({path, value})), set: (_, value) => writes.push(() => {current = value;})});
    writes.forEach(write => write()); return result;
  }};
}
test('platform build orders and exact app links are validated independently', () => {
  validateReleasePolicy('tv', policy); validateReleasePolicy('android', policy);
  for (const invalid of [{minimumBuild: 66}, {latestBuild: 66}, {publishedBuild: 64}, {enabled: true, published: false},
    {storeUrl: policy.storeUrl + '&id=other'}, {storeUrl: 'https://play.google.com/store/apps/details?id=other'}])
    assert.throws(() => validateReleasePolicy('tv', {...policy, ...invalid}));
  assert.throws(() => validateReleasePolicy('ios', policy));
});
test('uploaded internal or unavailable builds cannot become global update requirements', () => {
  validateAvailability('tv', policy, evidence, Date.parse(now));
  for (const invalid of [{track: 'internal'}, {installable: false}, {platform: 'android'}, {build: 64}, {version: '2.0'},
    {verifiedAt: '2026-09-01'}, {countries: []}, {deviceVerification: ''}, {verificationUrl: 'https://example.com'}])
    assert.throws(() => validateAvailability('tv', policy, {...evidence, ...invalid}, Date.parse(now)));
  validateAvailability('tv', {...policy, enabled: false}, null);
});
test('policy update atomically records previous/new values, actor, reason and evidence', async () => {
  const db = database(null);
  await applyReleasePolicy(db, {platform: 'tv', value: policy, expectedHash: policyHash(null), actor: 'operator', reason: 'Verified public availability', evidence, now, id: 'first'});
  assert.deepEqual(db.current(), policy); assert.equal(db.history.length, 1);
  assert.equal(db.history[0].value.before, null); assert.deepEqual(db.history[0].value.evidence, evidence);
  assert.equal(db.history[0].value.changedAt, now);
});
test('stale write and invalid operator metadata leave both policy and history unchanged', async () => {
  const db = database(policy); const args = {platform: 'tv', value: policy, expectedHash: policyHash(null), actor: 'operator', reason: 'Update verified', evidence, now};
  await assert.rejects(applyReleasePolicy(db, args), /Policy changed/);
  await assert.rejects(applyReleasePolicy(db, {...args, expectedHash: policyHash(policy), reason: ''}), /reason/);
  assert.equal(db.history.length, 0); assert.deepEqual(db.current(), policy);
});
test('restoration is a new audited write and emergency disable requires no store evidence', async () => {
  const db = database(policy); const disabled = {...policy, enabled: false};
  await applyReleasePolicy(db, {platform: 'tv', value: disabled, expectedHash: policyHash(policy), actor: 'operator', reason: 'Disable faulty update notice', restoreFrom: 'previous-change', now});
  assert.equal(db.current().enabled, false); assert.equal(db.history[0].value.restoreFrom, 'previous-change');
  assert.deepEqual(db.history[0].value.before, policy);
});
