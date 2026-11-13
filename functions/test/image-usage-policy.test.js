import test from 'node:test';
import assert from 'node:assert/strict';
import {imageUsagePolicies, usagePeriods, usageHash, requireUsageProject, usageConfigEnabled,
  imageUsagePolicyRevision, usageFailure} from '../src/image-usage-policy.js';
import {validateAdmissionWorkout, sourceAssetId, decodeAdmissionLocalImage} from '../src/class-admission.js';

test('exact decimal Free/Premium policy; no Plus usage product', () => {
  assert.deepEqual(imageUsagePolicies.free, {storageLimitBytes: 100000000, uploadDayLimitBytes: 30000000,
    imageLimitBytes: 100000000, downloadDayLimitBytes: 50000000, downloadMonthLimitBytes: 500000000});
  assert.deepEqual(imageUsagePolicies.premium, {storageLimitBytes: 1000000000, uploadDayLimitBytes: 500000000,
    imageLimitBytes: 100000000, downloadDayLimitBytes: 1000000000, downloadMonthLimitBytes: 20000000000});
  assert.deepEqual(Object.keys(imageUsagePolicies), ['free','premium']);
});
test('KST day/month boundary uses server UTC instant', () => {
  assert.deepEqual(usagePeriods(Date.parse('2026-11-30T14:59:59Z')), {
    dayKey: '2026-11-30', monthKey: '2026-11', dayReset: Date.parse('2026-11-30T15:00:00Z'),
    monthReset: Date.parse('2026-11-30T15:00:00Z')});
  assert.equal(usagePeriods(Date.parse('2026-11-30T15:00:00Z')).monthKey, '2026-12');
});
test('canonical request hash stable for object key order, sensitive to array order', () => {
  assert.equal(usageHash({z: [1,2], a: true}), usageHash({a: true, z: [1,2]}));
  assert.notEqual(usageHash([1,2]), usageHash([2,1]));
});
test('production/missing project/config cannot enable enforcement', () => {
  for (const project of [undefined, 'cloud-board-stationd', 'other-project']) assert.throws(() => requireUsageProject(project));
  requireUsageProject('cloud-board-development'); requireUsageProject('demo-usage-a');
  assert.equal(usageConfigEnabled(null, 'demo-usage-a'), false);
  assert.equal(usageConfigEnabled({schemaVersion:1,policyRevision:imageUsagePolicyRevision,enabled:true,allowedProjectIds:[]}, 'demo-usage-a'), false);
});
test('quota failures use fixed safe typed details', () => {
  const e = usageFailure('daily_transfer_limit', 'resource-exhausted');
  assert.equal(e.details.reason, 'daily_transfer_limit'); assert.equal(e.details.schemaVersion, 1);
  assert.equal(e.details.usage, null); assert.equal(e.details.retryable, false);
});
test('server workout validation rejects bad ownership and timing before admission', () => {
  const workout = {id:'w',ownerId:'owner',author:{id:'owner',displayName:'Coach'},name:'Test',folder:'',brandL:'',brandR:'',createdAt:1,updatedAt:2,
    modules:[{id:'module1',name:'Work',text:'',beep:true,coverImage:false,workSeconds:5,restSeconds:0,sets:1,imageUrl:''}]};
  assert.equal(validateAdmissionWorkout(workout,'owner').length,1);
  assert.throws(() => validateAdmissionWorkout({...workout,ownerId:'foreign'},'owner'));
  assert.throws(() => validateAdmissionWorkout({...workout,modules:[{...workout.modules[0],sets:0}]},'owner'));
});
test('configured emulator media source is exact, localhost-only, and rejects duplicate queries', () => {
  const ctx={projectId:'demo-usage',emulator:true,mediaBaseUrl:'http://127.0.0.1:5008/demo-usage/asia-northeast3/cloudboardMedia'};
  assert.deepEqual(sourceAssetId(ctx,`${ctx.mediaBaseUrl}?assetId=asset1&v=123`),{id:'asset1',generation:'123'});
  assert.equal(sourceAssetId(ctx,`${ctx.mediaBaseUrl}?assetId=asset1&v=123&v=456`),null);
  assert.equal(sourceAssetId(ctx,`${ctx.mediaBaseUrl}?assetId=asset1&v=123&token=raw`),null);
  assert.equal(sourceAssetId({...ctx,emulator:false},`${ctx.mediaBaseUrl}?assetId=asset1&v=123`),null);
  assert.equal(sourceAssetId({...ctx,mediaBaseUrl:'http://example.com/cloudboardMedia'},'http://example.com/cloudboardMedia?assetId=asset1&v=1'),null);
  assert.equal(sourceAssetId({...ctx,projectId:'cloud-board-development'},`${ctx.mediaBaseUrl}?assetId=asset1&v=123`),null);
});
test('existing embedded data URI/bare base64 images are validated and sized, arbitrary local strings refused', () => {
  const png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6N1sAAAAASUVORK5CYII=';
  const data=decodeAdmissionLocalImage(`data:image/png;base64,${png}`), bare=decodeAdmissionLocalImage(png);
  assert.equal(data.sizeBytes,Buffer.from(png,'base64').length);assert.equal(data.sha256,bare.sha256);
  assert.equal(data.contentType,'image/png');
  for(const source of ['assets/image.png','file:///tmp/a.png','asset://a','not an image','data:image/svg+xml;base64,PHN2Zy8+','data:image/png;base64,???']) {
    assert.throws(()=>decodeAdmissionLocalImage(source));
  }
});
