import test from 'node:test';
import assert from 'node:assert/strict';
import {Readable} from 'node:stream';
import {createCanvas} from '@napi-rs/canvas';
import {writeFile,mkdir} from 'node:fs/promises';
import {fixture,serve} from './media-gateway-fixtures.js';
import {handleMedia,handleMediaLease} from '../src/media-gateway.js';
import {HOME_MAX_BYTES, HOME_INPUT_BYTES, homeImageDimensions, renderHomeThumbnail,
  ensureHomeThumbnail, homeThumbnailRef, homeThumbnailPath, readHomeThumbnail} from '../src/home-image-thumbnail.js';
import {hashBytes} from '../src/managed-image-assets.js';

function artwork(width=960,height=540) {
  const canvas=createCanvas(width,height),g=canvas.getContext('2d');
  const gradient=g.createLinearGradient(0,0,width,height);
  gradient.addColorStop(0,'#264c43'); gradient.addColorStop(1,'#d3dcc3');
  g.fillStyle=gradient;g.fillRect(0,0,width,height);
  g.fillStyle='#fffdf8';g.font='bold 110px sans-serif';g.fillText('MOVE',60,250);
  g.font='40px sans-serif';g.fillText('TOGETHER',65,320);
  return canvas.toBuffer('image/png');
}
function setup(bytes=artwork()) {
  const s=fixture(bytes), original=s.ctx.bucket.file;
  s.ctx.bucket.file=(path,options)=>({...original(path,options),createReadStream:()=>{
    s.events.push(['stream',path,options]);
    return Readable.from([s.files.get(path).bytes]);
  }});
  return s;
}
const issue=(s,id='request_home_01')=>handleMediaLease(s.ctx,{schemaVersion:1,action:'issue',requestId:id,
  assetIds:[s.asset.assetId],admissionId:null,sessionId:null,purpose:'preview'},'owner');
const headers=lease=>({Authorization:'Bearer owner','X-CloudBoard-Media-Lease':lease.leaseId});

test('actual canvas rendition is image-only JPEG <=192px and <=64KiB',async()=>{
  const original=artwork(),result=await renderHomeThumbnail(original,'image/png');
  assert.equal(result.width,192);assert.equal(result.height,108);assert.ok(result.body.length<=HOME_MAX_BYTES);
  assert.ok(result.body.length<original.length);
  assert.deepEqual(homeImageDimensions(result.body,'image/jpeg'),{width:192,height:108});
  if(process.env.HOME_EVIDENCE){await mkdir(process.env.HOME_EVIDENCE,{recursive:true});
    await writeFile(`${process.env.HOME_EVIDENCE}/fixture-original.png`,original);
    await writeFile(`${process.env.HOME_EVIDENCE}/fixture-home.jpg`,result.body);}
});
test('dimension/byte/animation/type bounds reject before decoder and original stream',async()=>{
  const png=artwork();assert.equal(homeImageDimensions(png,'image/gif'),null);
  const giant=Buffer.from(png);giant.writeUInt32BE(100000,16);assert.equal(homeImageDimensions(giant,'image/png'),null);
  const animated=Buffer.concat([png.subarray(0,33),Buffer.from([0,0,0,0,97,99,84,76,0,0,0,0]),png.subarray(33)]);
  assert.equal(homeImageDimensions(animated,'image/png'),null);
  assert.equal(homeImageDimensions(Buffer.alloc(HOME_INPUT_BYTES+1),'image/png'),null);
  for(const mutate of [a=>a.sizeBytes=HOME_INPUT_BYTES+1,a=>a.contentType='image/webp']){
    const s=setup();mutate(s.asset);assert.equal(await ensureHomeThumbnail(s.ctx,s.asset),null);
    assert.equal(s.events.filter(e=>e[0]==='stream').length,0);
  }
});
test('upload bytes reuse has no Storage original read; repeated rendition reuses immutable result',async()=>{
  const s=setup(),first=await ensureHomeThumbnail(s.ctx,s.asset,s.bytes);
  assert.ok(first);assert.equal(s.events.filter(e=>e[0]==='stream').length,0);
  assert.deepEqual(await ensureHomeThumbnail(s.ctx,s.asset),{...first,claim:s.db.rows.get(homeThumbnailRef(s.ctx,s.asset).path).claim,
    attempts:1,expiresAtMs:0});
  assert.equal(s.events.filter(e=>e[0]==='save').length,1);
});
test('cold authenticated HTTP fetch reserves and settles thumbnail bytes, never original bytes',async()=>{
  const s=setup(),lease=await issue(s);const returned=[];
  await serve(handleMedia,s.ctx,async url=>{
    for(let i=0;i<2;i++){
      const r=await fetch(`${url}?assetId=image-one&v=7&rendition=home-v1`,{headers:headers(lease)});
      assert.equal(r.status,200);assert.equal(r.headers.get('content-type'),'image/jpeg');
      const body=Buffer.from(await r.arrayBuffer());returned.push(body.length);assert.ok(body.length<=HOME_MAX_BYTES);
    }
    const head=await fetch(`${url}?assetId=image-one&v=7&rendition=home-v1`,{method:'HEAD',headers:headers(lease)});
    assert.equal(head.status,200);assert.equal(Number(head.headers.get('content-length')),returned[0]);
  });
  assert.equal(s.events.filter(e=>e[0]==='stream'&&e[1]===s.asset.path).length,1);
  assert.equal(s.events.filter(e=>e[0]==='stream'&&e[1]===homeThumbnailPath(s.asset)).length,2);
  for(const [,r] of s.events.filter(e=>e[0]==='reserveTransfer')){
    assert.equal(r.sizeBytes,returned[0]);assert.equal(r.rendition,'home-v1');assert.equal(r.purpose,'preview');
    assert.equal(r.admissionId,null);assert.equal(r.sessionId,null);
  }
  assert.deepEqual(s.events.filter(e=>e[0]==='settleTransfer').map(e=>e[1].bodyBytes),returned);
  if(process.env.HOME_EVIDENCE)await writeFile(`${process.env.HOME_EVIDENCE}/http-byte-evidence.json`,JSON.stringify({
    originalBytes:s.bytes.length,renditionBytes:returned[0],clientRenditionGETs:2,clientOriginalGETs:0,
    serverColdOriginalReads:1,serverRenditionReads:2,bodyBytesTotal:returned.reduce((a,b)=>a+b),
    admissionRequests:0,externalServices:false},null,2));
});
test('bad owner, generation, lease, extra query and deleted account never receive thumbnail',async()=>{
  for(const mode of ['owner','generation','lease','query','deleted']){
    const s=setup(),lease=await issue(s);const h=headers(lease);
    if(mode==='owner')h.Authorization='Bearer other';if(mode==='lease')h['X-CloudBoard-Media-Lease']='missing';
    if(mode==='deleted')s.ctx.denyActor=true;
    await serve(handleMedia,s.ctx,async url=>{
      const r=await fetch(`${url}?assetId=image-one&v=${mode==='generation'?'8':'7'}&rendition=home-v1${mode==='query'?'&url=http://169.254.169.254':''}`,{headers:h});
      assert.ok(r.status>=400);
    });
    assert.equal(s.events.filter(e=>e[0]==='stream').length,0);
  }
});
test('concurrent cold generation makes one original read and one create',async()=>{
  const s=setup();const results=await Promise.all([ensureHomeThumbnail(s.ctx,s.asset),ensureHomeThumbnail(s.ctx,s.asset)]);
  assert.equal(results.filter(Boolean).length,1);
  assert.equal(s.events.filter(e=>e[0]==='stream').length,1);assert.equal(s.events.filter(e=>e[0]==='save').length,1);
});
test('failed/crashed claims retry at most twice; unsupported inputs are terminal',async()=>{
  const s=setup();const ref=homeThumbnailRef(s.ctx,s.asset);
  s.db.rows.set(ref.path,{status:'pending',claim:'crashed',attempts:1,expiresAtMs:1001});
  assert.equal(await ensureHomeThumbnail(s.ctx,s.asset),null);
  s.ctx.clock=()=>61002;assert.ok(await ensureHomeThumbnail(s.ctx,s.asset));
  const bad=setup(Buffer.from('invalid'));
  assert.equal(await ensureHomeThumbnail(bad.ctx,bad.asset),null);
  assert.equal(await ensureHomeThumbnail(bad.ctx,bad.asset),null);
  assert.equal(bad.events.filter(e=>e[0]==='stream').length,1);
  const failed=setup();const factory=failed.ctx.bucket.file;
  failed.ctx.bucket.file=(p,o)=>({...factory(p,o),createReadStream:()=>Readable.from((async function*(){throw Error('offline');})())});
  for(let i=0;i<3;i++)assert.equal(await ensureHomeThumbnail(failed.ctx,failed.asset),null);
  assert.equal(failed.db.rows.get(homeThumbnailRef(failed.ctx,failed.asset).path).attempts,2);
});
test('real stream cap, body integrity and generation-pinned derivative metadata fail closed',async()=>{
  const s=setup(),factory=s.ctx.bucket.file;
  s.ctx.bucket.file=(p,o)=>({...factory(p,o),createReadStream:()=>Readable.from([Buffer.alloc(HOME_INPUT_BYTES),Buffer.alloc(1)])});
  assert.equal(await ensureHomeThumbnail(s.ctx,s.asset),null);
  s.ctx.bucket.file=factory;const result=await ensureHomeThumbnail(s.ctx,s.asset);assert.ok(result);
  s.files.get(result.path).metadata.generation='999';await assert.rejects(readHomeThumbnail(s.ctx,s.asset,result));
  s.files.get(result.path).metadata.generation=result.generation;
  s.files.get(result.path).bytes=Buffer.from('tampered');await assert.rejects(readHomeThumbnail(s.ctx,s.asset,result));
});
test('old server/unavailable rendition has no original response fallback; original endpoint remains exact',async()=>{
  const s=setup(),lease=await issue(s);s.asset.sizeBytes=HOME_INPUT_BYTES+1;
  s.db.rows.set('imageUsageAccounts/owner/assets/image-one',s.asset);
  s.files.get(s.asset.path).metadata.size=s.asset.sizeBytes;
  await serve(handleMedia,s.ctx,async url=>assert.equal((await fetch(`${url}?assetId=image-one&v=7&rendition=home-v1`,{headers:headers(lease)})).status,404));
  assert.equal(s.events.filter(e=>e[0]==='stream').length,0);
  const normal=setup(),normalLease=await issue(normal);
  await serve(handleMedia,normal.ctx,async url=>{
    const response=await fetch(`${url}?assetId=image-one&v=7`,{headers:headers(normalLease)});
    assert.deepEqual(Buffer.from(await response.arrayBuffer()),normal.bytes);
  });
});
