import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {handleMedia,handleMediaLease,handleMediaRequest} from '../src/media-gateway.js';
import {fixture,png,serve} from './media-gateway-fixtures.js';
const issue=s=>handleMediaLease(s.ctx,{schemaVersion:1,action:'issue',requestId:'request_123',assetIds:['image-one'],admissionId:null,sessionId:null,purpose:'preview'},'owner');
const headers=lease=>({Authorization:'Bearer owner','X-CloudBoard-Media-Lease':lease.leaseId});
test('near-10MiB original body is one real buffered HTTP response; HEAD is metadata-only',async()=>{
  const s=fixture(png(10*1024*1024-1)),lease=await issue(s);
  await serve(handleMedia,s.ctx,async url=>{
    const response=await fetch(`${url}?assetId=image-one&v=7`,{headers:headers(lease)});
    assert.equal(response.status,200);assert.equal(response.headers.get('content-length'),String(s.bytes.length));
    assert.deepEqual(Buffer.from(await response.arrayBuffer()),s.bytes);
    const head=await fetch(`${url}?assetId=image-one&v=7`,{method:'HEAD',headers:headers(lease)});assert.equal(head.status,200);assert.equal((await head.arrayBuffer()).byteLength,0);
  });
  assert.equal(s.events.filter(e=>e[0]==='download').length,1);
  assert.equal(s.events.filter(e=>e[0]==='reserveTransfer').length,1);
  assert.equal(s.events.find(e=>e[0]==='download')[2].generation,'7');
  assert.equal(s.events.find(e=>e[0]==='settleTransfer')[1].bodyBytes,s.bytes.length);
  assert.ok(s.events.filter(e=>e[0]==='auth').every(e=>e[1]===true));
});
test('quota, wrong account, revoked token and revoked participant deny before GCS body',async()=>{
  for(const kind of ['quota','account','token','participant']){
    const s=fixture(),lease=await issue(s);if(kind==='quota')s.ctx.denyReserve=true;if(kind==='participant')s.ctx.denyActor=true;
    const h=headers(lease);if(kind==='account')h.Authorization='Bearer other';if(kind==='token')h.Authorization='Bearer revoked';
    await serve(handleMedia,s.ctx,async url=>{const r=await fetch(`${url}?assetId=image-one&v=7`,{headers:h});assert.equal(r.status,kind==='quota'?429:kind==='token'?401:403);});
    assert.equal(s.events.filter(e=>e[0]==='download').length,0);
  }
});
test('close/error are unknown and duplicate events cannot refund or double settle',async()=>{
  for(const event of ['close','error','finish']){
    const s=fixture(),lease=await issue(s),res=new EventEmitter();res.setHeader=()=>{};res.end=()=>{res.emit(event);res.emit('close');res.emit('finish');};
    await handleMedia(s.ctx,{method:'GET',headers:{authorization:'Bearer owner','x-cloudboard-media-lease':lease.leaseId},query:{assetId:'image-one',v:'7'}},res);
    const settlements=s.events.filter(e=>e[0]==='settleTransfer');assert.equal(settlements.length,1);assert.equal(settlements[0][1].outcome,event==='finish'?'served':'unknown');
  }
});
test('explicit CORS, Range refusal, and repeated lease requests get separate attempts',async()=>{
  const s=fixture(),lease=await issue(s);
  await serve(handleMedia,s.ctx,async url=>{
    const path=`${url}?assetId=image-one&v=7`;
    assert.equal((await fetch(path,{headers:{...headers(lease),Origin:'https://evil.example'}})).status,403);
    assert.equal((await fetch(path,{headers:{...headers(lease),Range:'bytes=1-2'}})).status,416);
    const pre=await fetch(path,{method:'OPTIONS',headers:{Origin:'http://localhost:5173'}});assert.equal(pre.status,204);assert.equal(pre.headers.get('access-control-allow-origin'),'http://localhost:5173');
    for(let i=0;i<2;i++)await(await fetch(path,{headers:headers(lease)})).arrayBuffer();
  });
  assert.equal(s.events.filter(e=>e[0]==='reserveTransfer').length,2);
});
test('generation or manifest changes reject a lease before fetching Storage body',async()=>{
  const s=fixture();
  s.db.rows.set('imageUsageAccounts/owner/admissions/adm',{sessionId:'session',status:'active',epoch:4,manifestHash:'hash',assets:[s.asset]});
  const lease=await handleMediaLease(s.ctx,{schemaVersion:1,action:'issue',requestId:'request_123',assetIds:['image-one'],admissionId:'adm',sessionId:'session',purpose:'playback'},'owner');
  s.db.rows.get('imageUsageAccounts/owner/admissions/adm').epoch=5;
  await serve(handleMedia,s.ctx,async url=>{assert.equal((await fetch(`${url}?assetId=image-one&v=7`,{headers:headers(lease)})).status,403);});
  assert.equal(s.events.filter(e=>e[0]==='download').length,0);
});

test('failed generation-pinned Storage read is settled as not_sent before any image body',async()=>{
  const s=fixture(),lease=await issue(s),original=s.ctx.bucket.file;
  s.ctx.bucket.file=(p,o)=>({...original(p,o),download:async()=>{throw Error('storage unavailable');}});
  await serve(handleMedia,s.ctx,async url=>{const r=await fetch(`${url}?assetId=image-one&v=7`,{headers:headers(lease)});assert.equal(r.status,503);});
  assert.equal(s.events.find(e=>e[0]==='settleTransfer')[1].outcome,'not_sent');
});
test('expired lease is refused without Storage reads',async()=>{
  const s=fixture(),lease=await issue(s);s.ctx.clock=()=>lease.expiresAtMs;
  await serve(handleMedia,s.ctx,async url=>{assert.equal((await fetch(`${url}?assetId=image-one&v=7`,{headers:headers(lease)})).status,403);});
  assert.equal(s.events.filter(e=>e[0]==='metadata').length,0);
});

test('public media callable and HTTP context signatures match root runtime',async()=>{
  const s=fixture();
  const lease=await handleMediaLease({...s.ctx,actor:{uid:'owner',token:{}},input:{schemaVersion:1,action:'issue',requestId:'public_context_request',assetIds:['image-one'],admissionId:null,sessionId:null,purpose:'preview'}});
  await serve((ctx,request,response)=>handleMediaRequest({...ctx,request,response}),s.ctx,async url=>{
    const result=await fetch(`${url}?assetId=image-one&v=7`,{headers:headers(lease)});assert.equal(result.status,200);assert.deepEqual(Buffer.from(await result.arrayBuffer()),s.bytes);
  });
});

test('paired standby TV preview is restricted to fresh authoritative brand sources and pairing',async()=>{
  const s=fixture();s.ctx.actorBindings={tv:{ownerId:'owner',deviceId:'screen',deviceBinding:{displayUid:'tv',pairingCode:'pair-one',pairedAtMs:10}}};
  s.ctx.previewSources=[s.asset.source];
  const input={schemaVersion:1,action:'issue',requestId:'standby_request',assetIds:['image-one'],admissionId:null,sessionId:null,purpose:'preview'};
  const lease=await handleMediaLease(s.ctx,input,'tv');
  const stored=s.db.rows.get(`imageUsageMediaLeases/${lease.leaseId}`);
  stored.deviceBinding={pairedAtMs:10,pairingCode:'pair-one',displayUid:'tv'}; // Firestore map field order is not identity.
  const tvHeaders={Authorization:'Bearer tv','X-CloudBoard-Media-Lease':lease.leaseId};
  await serve(handleMedia,s.ctx,async url=>{
    const path=`${url}?assetId=image-one&v=7`;
    assert.equal((await fetch(path,{headers:tvHeaders})).status,200);
    s.ctx.previewSources=[];assert.equal((await fetch(path,{headers:tvHeaders})).status,403);
    s.ctx.previewSources=[s.asset.source];s.ctx.actorBindings.tv.deviceBinding.pairingCode='pair-two';
    assert.equal((await fetch(path,{headers:tvHeaders})).status,403);
  });
  assert.equal(s.events.filter(e=>e[0]==='download').length,1);
  assert.ok(s.events.filter(e=>e[0]==='reserveTransfer').every(e=>e[1].purpose==='preview'&&e[1].sessionId===null));
  s.ctx.previewSources=[];
  await assert.rejects(handleMediaLease(s.ctx,{...input,requestId:'standby_deny'},'tv'),e=>e.details.reason==='media_lease_invalid');
});
test('brand source changed during Storage read is denied again before body handoff',async()=>{
  const s=fixture();s.ctx.actorBindings={tv:{ownerId:'owner',deviceId:'screen',deviceBinding:{displayUid:'tv',pairingCode:'pair-one',pairedAtMs:10}}};s.ctx.previewSources=[s.asset.source];
  const lease=await handleMediaLease(s.ctx,{schemaVersion:1,action:'issue',requestId:'standby_read',assetIds:['image-one'],admissionId:null,sessionId:null,purpose:'preview'},'tv');
  const original=s.ctx.bucket.file;s.ctx.bucket.file=(p,o)=>({...original(p,o),download:async()=>{const result=await original(p,o).download();s.ctx.previewSources=[];return result;}});
  await serve(handleMedia,s.ctx,async url=>assert.equal((await fetch(`${url}?assetId=image-one&v=7`,{headers:{Authorization:'Bearer tv','X-CloudBoard-Media-Lease':lease.leaseId}})).status,403));
  assert.equal(s.events.find(e=>e[0]==='settleTransfer')[1].outcome,'not_sent');
});
