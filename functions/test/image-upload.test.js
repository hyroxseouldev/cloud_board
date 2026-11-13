import test from 'node:test';
import assert from 'node:assert/strict';
import {handleImageUpload,handleImageUploadBody,handleImageUploadRequest,reserveGeneratedImage,storeGeneratedImage,enrolledAssetResponse} from '../src/image-upload.js';
import {hashBytes} from '../src/managed-image-assets.js';
import {fixture,png,serve} from './media-gateway-fixtures.js';
const reserve=(s,extra={})=>handleImageUpload(s.ctx,{schemaVersion:1,action:'reserve',requestId:'upload_request',purpose:'workout',workoutId:null,sha256:hashBytes(s.bytes),sizeBytes:s.bytes.length,contentType:'image/png',...extra},'owner');
const headers=p=>({Authorization:'Bearer owner','X-CloudBoard-Upload-Id':p.uploadId,'Content-Type':'image/png'});
test('raw upload validates bytes, private create-only metadata and lost acknowledgement readback',async()=>{
  const s=fixture(),permit=await reserve(s);
  const original=s.ctx.bucket.file;s.ctx.bucket.file=(p,o)=>({...original(p,o),save:async(b,opt)=>{await original(p,o).save(b,opt);throw Error('lost acknowledgement');}});
  await serve(handleImageUploadBody,s.ctx,async url=>{
    const response=await fetch(url,{method:'POST',headers:headers(permit),body:s.bytes});assert.equal(response.status,201);
    const saved=(await response.json()).upload;assert.equal(saved.status,'stored');assert.equal(saved.asset.sha256,hashBytes(s.bytes));assert.ok(!saved.asset.source.includes('token='));
    const duplicate=await fetch(url,{method:'POST',headers:headers(permit),body:s.bytes});assert.equal(duplicate.status,201);
    const wrong=await fetch(url,{method:'POST',headers:headers(permit),body:png(41)});assert.equal(wrong.status,400);
  });
  const saves=s.events.filter(e=>e[0]==='save');assert.equal(saves.length,1);assert.deepEqual(saves[0][2].preconditionOpts,{ifGenerationMatch:0});
  assert.equal(saves[0][2].metadata.metadata.firebaseStorageDownloadTokens,undefined);
  const get=await handleImageUpload(s.ctx,{schemaVersion:1,action:'get',uploadId:permit.uploadId},'owner');assert.equal(get.status,'stored');
});
test('bounds, incorrect hash/size/MIME/signature and account deny before writer claim',async()=>{
  const s=fixture();
  for(const extra of [{sizeBytes:10485760},{purpose:'profile',sizeBytes:5242880},{sizeBytes:0},{sha256:'x'},{contentType:'image/svg+xml'}])await assert.rejects(reserve(s,extra));
  for(const kind of ['size','hash','mime','signature','account','revoked']){
    const s=fixture(),p=await reserve(s),h=headers(p);let bytes=Buffer.from(s.bytes);
    if(kind==='size')bytes=Buffer.concat([bytes,Buffer.from([0])]);if(kind==='hash')bytes[30]++;if(kind==='signature')bytes[0]=0;if(kind==='mime')h['Content-Type']='image/jpeg';if(kind==='account')h.Authorization='Bearer other';if(kind==='revoked')h.Authorization='Bearer revoked';
    await serve(handleImageUploadBody,s.ctx,async url=>{const response=await fetch(url,{method:'POST',headers:h,body:bytes});assert.equal(response.status,kind==='account'?403:kind==='revoked'?401:400);});
    assert.equal(s.events.filter(e=>e[0]==='save').length,0);assert.equal(s.events.filter(e=>e[0]==='beginUpload').length,0);
  }
});
test('uncertain writes keep reservation unknown; get reconciles later object without new upload',async()=>{
  const s=fixture(),p=await reserve(s),original=s.ctx.bucket.file;let captured;
  s.ctx.bucket.file=(path,o)=>({...original(path,o),save:async(b,opt)=>{captured={path,b,opt};throw Error('timeout');}});
  await serve(handleImageUploadBody,s.ctx,async url=>{const r=await fetch(url,{method:'POST',headers:headers(p),body:s.bytes});assert.equal(r.status,503);assert.equal((await r.json()).error.reason,'usage_reconciliation_pending');});
  assert.equal((await handleImageUpload(s.ctx,{schemaVersion:1,action:'get',uploadId:p.uploadId},'owner')).status,'unknown');
  await original(captured.path).save(captured.b,captured.opt);
  const settled=await handleImageUpload(s.ctx,{schemaVersion:1,action:'get',uploadId:p.uploadId},'owner');assert.equal(settled.status,'stored');
  assert.equal(s.events.filter(e=>e[0]==='reserveUpload').length,1);
});
test('cancellation delegates only unclaimed reserved records and retains writing ambiguity',async()=>{
  const s=fixture(),p=await reserve(s);await s.ctx.ledger.beginUpload(s.ctx,{uploadId:p.uploadId});
  const result=await handleImageUpload(s.ctx,{schemaVersion:1,action:'cancel',requestId:'cancel_request',uploadId:p.uploadId},'owner');assert.equal(result.status,'writing');
  assert.equal(s.events.filter(e=>e[0]==='settleUpload').length,0);
});
test('enrolled generated image reserves maximum before provider, settles actual and returns descriptor',async()=>{
  const s=fixture();s.db.rows.set('imageUsageAccounts/owner',{mode:'enrolled'});
  const reservation=await reserveGeneratedImage({db:s.db,bucket:s.ctx.bucket,uid:'owner',usageContext:s.ctx},'job-1','ai_slide_raster');
  const reserved=s.events.find(e=>e[0]==='reserveUpload')[1];
  assert.equal(reserved.sizeBytes,10485759);assert.equal(reserved.sha256,null);assert.equal(reserved.generatedOutput.hashStatus,'pending');
  const asset=await storeGeneratedImage(reservation,png(100));assert.equal(asset.sizeBytes,100);assert.equal(asset.provenance,'ai_slide_raster');
  const response=await enrolledAssetResponse({db:s.db,uid:'owner',usageContext:s.ctx},{...asset,width:100,height:100});assert.equal(response.schemaVersion,1);assert.equal(response.base64,undefined);assert.equal(response.asset.source,asset.source);
  await assert.rejects(enrolledAssetResponse({db:s.db,uid:'owner',usageContext:s.ctx},{path:'legacy'}),e=>e.details.reason==='legacy_asset_transition_required');
});

test('cancel mutation idempotency rejects a reused request key with different upload',async()=>{
  const s=fixture(),p=await reserve(s),p2=await reserve(s,{requestId:'another_upload'});
  const cancel={schemaVersion:1,action:'cancel',requestId:'same_cancel_request',uploadId:p.uploadId};
  assert.equal((await handleImageUpload(s.ctx,cancel,'owner')).status,'cancelled');
  assert.equal((await handleImageUpload(s.ctx,cancel,'owner')).status,'cancelled');
  await assert.rejects(handleImageUpload(s.ctx,{...cancel,uploadId:p2.uploadId},'owner'),e=>e.details.reason==='idempotency_conflict');
});
test('generated upload requery settles smaller output after a lost stored-result acknowledgement',async()=>{
  const s=fixture();s.db.rows.set('imageUsageAccounts/owner',{mode:'enrolled'});
  const reservation=await reserveGeneratedImage({db:s.db,bucket:s.ctx.bucket,uid:'owner',usageContext:s.ctx},'recover-job','template_job');
  const original=s.ctx.ledger.settleUpload;let lose=true;
  s.ctx.ledger.settleUpload=async(ctx,args)=>{if(args.outcome==='stored'&&lose){lose=false;throw Error('ledger response lost');}return original(ctx,args);};
  await assert.rejects(storeGeneratedImage(reservation,png(101)));
  const recovered=await storeGeneratedImage(reservation,png(101));assert.equal(recovered.sizeBytes,101);
  assert.equal(s.events.filter(e=>e[0]==='save').length,1);
});

test('public callable and HTTP handler context signatures match root runtime',async()=>{
  const s=fixture();
  const permit=await handleImageUpload({...s.ctx,actor:{uid:'owner',token:{}},input:{schemaVersion:1,action:'reserve',requestId:'public_context_request',purpose:'workout',workoutId:null,sha256:hashBytes(s.bytes),sizeBytes:s.bytes.length,contentType:'image/png'}});
  await serve((ctx,request,response)=>handleImageUploadRequest({...ctx,request,response}),s.ctx,async url=>{
    assert.equal((await fetch(url,{method:'POST',headers:headers(permit),body:s.bytes})).status,201);
  });
});

test('raw clients cannot reserve or submit internal pending-hash generated output',async()=>{
  const s=fixture();await assert.rejects(reserve(s,{purpose:'generated',sha256:null,generatedOutput:{hashStatus:'pending'}}));
  s.db.rows.set('imageUsageAccounts/owner',{mode:'enrolled'});
  const pending=await reserveGeneratedImage({db:s.db,bucket:s.ctx.bucket,uid:'owner',usageContext:s.ctx},'internal','template_job');
  await serve(handleImageUploadBody,s.ctx,async url=>assert.equal((await fetch(url,{method:'POST',headers:headers(pending.record),body:s.bytes})).status,403));
  assert.equal(s.events.filter(e=>e[0]==='save').length,0);
});

test('claimed upload without object remains retryable pending and cannot obtain a second writer',async()=>{
  const s=fixture(),p=await reserve(s);await s.ctx.ledger.beginUpload(s.ctx,{uploadId:p.uploadId});
  await serve(handleImageUploadBody,s.ctx,async url=>{
    const response=await fetch(url,{method:'POST',headers:headers(p),body:s.bytes});assert.equal(response.status,503);assert.equal((await response.json()).error.reason,'usage_reconciliation_pending');
  });
  assert.equal(s.events.filter(e=>e[0]==='beginUpload').length,1);assert.equal(s.events.filter(e=>e[0]==='save').length,0);
});
