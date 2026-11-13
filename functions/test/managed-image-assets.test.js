import test from 'node:test';
import assert from 'node:assert/strict';
import {parseManagedSource,assetSource,readManagedAsset,managedMetadata,validateImage} from '../src/managed-image-assets.js';
import {fixture,png} from './media-gateway-fixtures.js';
import {workoutImageBudgetChecker} from '../src/workout-image-budget.js';
test('stable source parser accepts only explicit project/function URL, never arbitrary URL/token/extra query',()=>{
  const s=fixture(),source=assetSource(s.ctx,'asset','123');assert.deepEqual(parseManagedSource(source,s.ctx),{assetId:'asset',generation:'123'});
  for(const url of ['https://evil.example/cloudboardMedia?assetId=asset&v=1',source+'&token=x',source+'&v=2',source.replace('127.0.0.1','evil.example'),'http://169.254.169.254/latest/meta-data'])assert.equal(parseManagedSource(url,s.ctx),null);
  assert.throws(()=>assetSource({...s.ctx,projectId:'cloud-board-stationd'},'asset','1'));
});
test('registry owner/generation and token-free metadata are checked without client URL fetch',async()=>{
  const s=fixture();await readManagedAsset(s.ctx,'owner','image-one','7');
  await assert.rejects(readManagedAsset(s.ctx,'other','image-one','7'));
  await assert.rejects(readManagedAsset(s.ctx,'owner','image-one','8'));
  s.files.get(s.asset.path).metadata.contentEncoding='gzip';await assert.rejects(managedMetadata(s.ctx,s.asset));
  delete s.files.get(s.asset.path).metadata.contentEncoding;
  s.files.get(s.asset.path).metadata.metadata.firebaseStorageDownloadTokens='token';await assert.rejects(managedMetadata(s.ctx,s.asset));
});
test('workout budget counts managed stable asset generation and keeps historical external editing',async()=>{
  const s=fixture(),checker=workoutImageBudgetChecker(s.ctx.bucket,'owner',{managedContext:s.ctx});
  const result=await checker({modules:[{imageUrl:s.asset.source},{imageUrl:s.asset.source}]},null);assert.equal(result.totalBytes,s.bytes.length);
  assert.equal(s.events.filter(e=>e[0]==='download').length,0);
  const external={modules:[{imageUrl:'https://legacy.example/image.png'}]};assert.equal((await checker(external,external)).unknownCount,1);
  await assert.rejects(checker(external,null));
});
test('signature and exclusive byte limits preserve existing image bounds',()=>{
  validateImage(png(),'image/png');assert.throws(()=>validateImage(png(10485760),'image/png'));assert.throws(()=>validateImage(png(5242880),'image/png','profile'));
  assert.throws(()=>validateImage(png(),'image/jpeg'));assert.throws(()=>validateImage(Buffer.from('<svg/>'),'image/svg+xml'));
});
