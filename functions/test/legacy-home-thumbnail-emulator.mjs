// Real local Firestore/RTDB/Storage and HTTP. Auth identity is injected; this
// does not claim deployed callable auth, a real account, or Flutter app E2E.
import assert from 'node:assert/strict';
import {mkdir,writeFile} from 'node:fs/promises';
import {Readable} from 'node:stream';
import {execFileSync} from 'node:child_process';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore,Timestamp} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {getStorage} from 'firebase-admin/storage';
import {hashBytes} from '../src/managed-image-assets.js';
import {handleMedia} from '../src/media-gateway.js';
import {readUsage,reserveTransfer} from '../src/image-usage-ledger.js';
import {resolveLegacyHomeAsset} from '../src/legacy-home-image.js';
import {homeThumbnailPath,homeThumbnailRef,homeImageDimensions} from '../src/home-image-thumbnail.js';
import {serve} from './media-gateway-fixtures.js';

for(const key of ['FIRESTORE_EMULATOR_HOST','FIREBASE_DATABASE_EMULATOR_HOST','FIREBASE_STORAGE_EMULATOR_HOST'])
  assert.match(process.env[key]??'',/^(127\.0\.0\.1|localhost):\d+$/);
const projectId='demo-cloudboard-home';assert.equal(process.env.GCLOUD_PROJECT,projectId);
const app=initializeApp({projectId,databaseURL:`https://${projectId}-default-rtdb.firebaseio.com`,storageBucket:`${projectId}.appspot.com`},'legacy-home');
const db=getFirestore(app),realtime=getDatabase(app),bucket=getStorage(app).bucket();
const ownerId='legacy-home-fixture',updatedAtMs=1800000000000,events=[];
let beforeRead=null;
const ctx={db,realtime,projectId,clock:()=>updatedAtMs,emulator:true,
  mediaBaseUrl:`http://127.0.0.1:5501/${projectId}/asia-northeast3/cloudboardMedia`,
  auth:{verifyIdToken:async token=>({uid:token,firebase:{sign_in_provider:'password'}})},
  bucket:{name:bucket.name,file:(path,opts)=>{
    const file=bucket.file(path,opts),read=file.createReadStream.bind(file);
    file.createReadStream=options=>Readable.from((async function*(){
      events.push({path,generation:opts?.generation??null});
      if(beforeRead)await beforeRead(path);
      yield* read(options);
    })());return file;
  }}};
const evidence=process.env.HOME_EVIDENCE;
const headers={Authorization:`Bearer ${ownerId}`};
function artwork(width,height,type) {
  // The gateway receives encoded uploads, it does not paint full-size fixtures.
  // Isolate fixture creation so those native canvases do not consume its RSS budget.
  return execFileSync(process.execPath,['--input-type=module','-e',`
    import {createCanvas} from '@napi-rs/canvas';
    const width=${width},height=${height},canvas=createCanvas(width,height),g=canvas.getContext('2d');
    g.fillStyle='#243f37';g.fillRect(0,0,width,height);
    for(let y=0;y<height;y+=48){g.fillStyle=y%96?'#526b60':'#c0cfba';g.fillRect(0,y,width,24);}
    g.fillStyle='#fffdf8';g.fillRect(width/10,height/3,width*.8,height/3);
    g.fillStyle='#263f35';g.font='bold '+Math.floor(width/16)+'px sans-serif';g.fillText('MOVE TOGETHER',width*.14,height*.53);
    process.stdout.write(canvas.toBuffer(${JSON.stringify(type)}));
  `],{cwd:new URL('../',import.meta.url),maxBuffer:10*1024*1024});
}
async function seed(id,path,bytes,type) {
  const file=bucket.file(path);
  await file.save(bytes,{resumable:false,metadata:{contentType:type,metadata:{firebaseStorageDownloadTokens:'existing-token'}}});
  const source=`https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=existing-token`;
  const input={workoutId:id,sourceHash:hashBytes(source),updatedAtMs};
  const summary={id,imageSource:source,updatedAt:Timestamp.fromMillis(updatedAtMs)};
  const workout={id,ownerId,author:{id:ownerId},modules:[{imageUrl:source}],updatedAt:Timestamp.fromMillis(updatedAtMs)};
  await db.doc(`users/${ownerId}/workouts/${id}`).set(workout);
  await db.doc(`users/${ownerId}/workoutSummaries/${id}`).set(summary);
  return {id,path,input,source,summary,workout,bytes,type};
}
const query=f=>`?${new URLSearchParams({rendition:'home-v1',...f.input,updatedAtMs:String(updatedAtMs)})}`;
try {
  if(evidence)await mkdir(evidence,{recursive:true});
  await db.doc(`imageUsageAccounts/${ownerId}`).set({mode:'observe',policyPlan:'free',revision:0,
    storageUsedBytes:0,storageReservedBytes:0,storageUnknownBytes:0,inventoryComplete:false});
  await realtime.ref(`users/${ownerId}`).set({uid:ownerId});
  const fixtures=[
    await seed('copied-png',`users/${ownerId}/workouts/source-class/images/${'c'.repeat(64)}`,artwork(3840,2160,'image/png'),'image/png'),
    await seed('historical-jpeg',`users/${ownerId}/workouts/source-old/modules/slide/background`,artwork(2560,1440,'image/jpeg'),'image/jpeg'),
  ];
  const report={projectId,auth:'injected local password identity',externalServices:false,fixtures:[],rssBeforeGateway:process.memoryUsage().rss};
  let transferred=0;
  await serve(handleMedia,ctx,async base=>{
    for(const f of fixtures){
      const endpoint=base+query(f),[originalMeta]=await bucket.file(f.path).getMetadata();
      assert.equal((await fetch(endpoint,{headers,method:'HEAD'})).status,404);
      let body;
      for(let i=0;i<2;i++){
        const r=await fetch(endpoint,{headers});assert.equal(r.status,200,await r.clone().text());
        body=Buffer.from(await r.arrayBuffer());transferred+=body.length;
        assert.ok(body.length<=65536);assert.equal(r.headers.get('cache-control'),'private,no-store');
        assert.deepEqual(homeImageDimensions(body,'image/jpeg'),{width:192,height:108});
      }
      assert.equal((await fetch(endpoint,{headers,method:'HEAD'})).status,200);
      const current=await resolveLegacyHomeAsset(ctx,ownerId,f.input),manifest=(await homeThumbnailRef(ctx,current).get()).data();
      assert.equal(manifest.attempts,1);assert.equal(manifest.originalSha256,hashBytes(f.bytes));
      const [derivative]=await bucket.file(manifest.path).getMetadata();
      assert.equal(derivative.metadata.firebaseStorageDownloadTokens,undefined);assert.equal(derivative.cacheControl,'private,no-store');
      const [afterMeta]=await bucket.file(f.path).getMetadata();assert.equal(afterMeta.generation,originalMeta.generation);
      assert.equal(afterMeta.metadata.firebaseStorageDownloadTokens,'existing-token');
      assert.deepEqual((await bucket.file(f.path).download())[0],f.bytes);
      assert.equal(events.filter(e=>e.path===f.path).length,1);
      const baseTransfer={ownerId,actorUid:ownerId,deviceId:null,leaseId:null,assetId:current.assetId,generation:current.generation,
        rendition:'home-v1',legacyHome:current,sizeBytes:body.length,admissionId:null,sessionId:null,purpose:'preview'};
      for(const bad of [{sizeBytes:body.length-1},{sizeBytes:f.bytes.length},{rendition:undefined},
        {legacyHome:{...current,path:current.path.replace(ownerId,'other')}},{generation:'999'}])
        await assert.rejects(reserveTransfer(ctx,{...baseTransfer,...bad}));
      await db.doc(`users/${ownerId}/workoutSummaries/${f.id}`).update({updatedAt:Timestamp.fromMillis(updatedAtMs+1)});
      await assert.rejects(reserveTransfer(ctx,baseTransfer));
      assert.equal((await fetch(endpoint,{headers})).status,403);
      await db.doc(`users/${ownerId}/workoutSummaries/${f.id}`).set(f.summary);
      if(evidence){await writeFile(`${evidence}/${f.id}-original.${f.type==='image/png'?'png':'jpg'}`,f.bytes);
        await writeFile(`${evidence}/${f.id}-home.jpg`,body);}
      report.fixtures.push({id:f.id,originalBytes:f.bytes.length,renditionBytes:body.length,serverOriginalReads:1,
        originalGeneration:current.generation,derivativeGeneration:manifest.generation,thumbnailAttempts:1});
    }
    const f=fixtures[0],endpoint=base+query(f);
    // Installed legacy writers use Timestamp.fromDate(DateTime.now), retaining
    // microseconds. The client sends millis, the server pins full precision.
    const micro=new Timestamp(Math.floor(updatedAtMs/1000),123000);
    await db.doc(`users/${ownerId}/workouts/${f.id}`).update({updatedAt:micro});
    await db.doc(`users/${ownerId}/workoutSummaries/${f.id}`).update({updatedAt:micro});
    assert.equal((await fetch(endpoint,{headers,method:'HEAD'})).status,200);
    const microAsset=await resolveLegacyHomeAsset(ctx,ownerId,f.input);
    const changedMicro=new Timestamp(Math.floor(updatedAtMs/1000),456000);
    await db.doc(`users/${ownerId}/workouts/${f.id}`).update({updatedAt:changedMicro});
    await db.doc(`users/${ownerId}/workoutSummaries/${f.id}`).update({updatedAt:changedMicro});
    await assert.rejects(reserveTransfer(ctx,{ownerId,actorUid:ownerId,deviceId:null,leaseId:null,assetId:microAsset.assetId,
      generation:microAsset.generation,rendition:'home-v1',legacyHome:microAsset,sizeBytes:report.fixtures[0].renditionBytes,
      admissionId:null,sessionId:null,purpose:'preview'}));
    await db.doc(`users/${ownerId}/workouts/${f.id}`).set(f.workout);
    await db.doc(`users/${ownerId}/workoutSummaries/${f.id}`).set(f.summary);
    assert.equal((await fetch(endpoint,{headers:{Authorization:'Bearer different-owner'}})).status,403);
    // A real RTDB revocation and Firestore enrollment fence block both methods.
    await realtime.ref(`authAccess/${ownerId}`).set({disabled:true});
    for(const method of ['GET','HEAD'])assert.equal((await fetch(endpoint,{headers,method})).status,403);
    await realtime.ref(`authAccess/${ownerId}`).remove();
    for(const mode of ['enrolling','enrolled']){
      await db.doc(`imageUsageAccounts/${ownerId}`).update({mode});
      assert.equal((await fetch(endpoint,{headers})).status,403);
    }
    await db.doc(`imageUsageAccounts/${ownerId}`).update({mode:'observe'});
    // Canonical deletion during the actual derivative stream is settled zero.
    const asset=await resolveLegacyHomeAsset(ctx,ownerId,f.input);
    beforeRead=async path=>{if(path===homeThumbnailPath(asset))await db.doc(`users/${ownerId}/workouts/${f.id}`).delete();};
    assert.equal((await fetch(endpoint,{headers})).status,403);beforeRead=null;
    await db.doc(`users/${ownerId}/workouts/${f.id}`).set(f.workout);
    // Same legacy URL overwritten in Storage gets a new generation and claim.
    await bucket.file(f.path).save(f.bytes,{resumable:false,metadata:{contentType:f.type,metadata:{firebaseStorageDownloadTokens:'existing-token'}}});
    const changed=await resolveLegacyHomeAsset(ctx,ownerId,f.input);assert.notEqual(changed.generation,asset.generation);
    const replacement=await fetch(endpoint,{headers});assert.equal(replacement.status,200);transferred+=(await replacement.arrayBuffer()).byteLength;
    assert.equal((await homeThumbnailRef(ctx,changed).get()).data().attempts,1);
    await bucket.file(f.path).delete();
    assert.ok((await fetch(endpoint,{headers})).status>=400);
    await db.doc(`accountDeletions/${ownerId}`).set({status:'processing'});
    assert.equal((await fetch(base+query(fixtures[1]),{headers})).status,403);
  });
  // readUsage itself rejects deleted accounts; inspect final period evidence.
  await db.doc(`accountDeletions/${ownerId}`).delete();
  const usage=await readUsage(ctx,{ownerId});
  assert.equal(usage.downloadDay.usedBytes,transferred);assert.equal(usage.downloadMonth.usedBytes,transferred);
  assert.equal(usage.downloadDay.reservedBytes,0);assert.equal(usage.downloadDay.unknownBytes,0);
  assert.equal(usage.uploadDay.usedBytes,0);assert.equal(usage.storage.usedBytes,0);assert.equal(usage.storage.reservedBytes,0);
  const attempts=await db.collection(`imageUsageAccounts/${ownerId}/attempts`).get();
  assert.equal(attempts.docs.filter(d=>d.data().status==='not_sent').length,1);
  assert.equal(attempts.docs.filter(d=>d.data().status==='served').length,5);
  for(const name of ['admissions','assets','uploads'])assert.equal((await db.collection(`imageUsageAccounts/${ownerId}/${name}`).get()).size,0);
  // Same operations as existing account cleanup; no new GC or deletion code.
  await db.doc(`accountDeletions/${ownerId}`).set({status:'processing'});
  await bucket.deleteFiles({prefix:`users/${ownerId}/`});await db.recursiveDelete(db.doc(`users/${ownerId}`));
  assert.equal((await bucket.getFiles({prefix:`users/${ownerId}/`}))[0].length,0);
  assert.equal((await db.collection(`users/${ownerId}/homeThumbnails`).get()).size,0);
  Object.assign(report,{downloadDayUsedBytes:usage.downloadDay.usedBytes,downloadMonthUsedBytes:usage.downloadMonth.usedBytes,
    servedAttempts:5,notSentAttempts:1,reservedBytes:0,admissions:0,assetEnrollments:0,uploads:0,
    originalClientGETs:0,accountCleanupVerified:true,storageOverwriteGenerationsVerified:true,
    quotaPolicy:'observe meters actual bytes without enforcement; enrolled legacy denied (unchanged direct-image fence)'});
  if(evidence)await writeFile(`${evidence}/legacy-emulator-evidence.json`,JSON.stringify(report,null,2));
  console.log('PASS legacy real Storage/Firestore/RTDB/HTTP rendition contract',report);
} finally {await deleteApp(app);}
