// Real local Firestore/RTDB/Storage + HTTP gateway; injected local identity,
// not deployed callable auth, app E2E, real account or external-service evidence.
import assert from 'node:assert/strict';
import {writeFile} from 'node:fs/promises';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getDatabase} from 'firebase-admin/database';
import {getStorage} from 'firebase-admin/storage';
import {createCanvas} from '@napi-rs/canvas';
import {assetSource,hashBytes} from '../src/managed-image-assets.js';
import {handleMedia,handleMediaLease} from '../src/media-gateway.js';
import {readUsage,reserveTransfer} from '../src/image-usage-ledger.js';
import {imageUsagePolicyRevision} from '../src/image-usage-policy.js';
import {homeThumbnailRef,homeThumbnailPath} from '../src/home-image-thumbnail.js';
import {serve} from './media-gateway-fixtures.js';
for (const key of ['FIRESTORE_EMULATOR_HOST','FIREBASE_DATABASE_EMULATOR_HOST','FIREBASE_STORAGE_EMULATOR_HOST'])
  assert.match(process.env[key]??'',/^(127\.0\.0\.1|localhost):\d+$/);
const projectId='demo-cloudboard-home';assert.equal(process.env.GCLOUD_PROJECT,projectId);
const app=initializeApp({projectId,databaseURL:`https://${projectId}-default-rtdb.firebaseio.com`,storageBucket:`${projectId}.appspot.com`});
const db=getFirestore(app),realtime=getDatabase(app),bucket=getStorage(app).bucket();
const ownerId='home-fixture-owner',now=Date.now();
const ctx={db,realtime,bucket,projectId,clock:()=>now,emulator:true,
  mediaBaseUrl:`http://127.0.0.1:5501/${projectId}/asia-northeast3/cloudboardMedia`,
  auth:{verifyIdToken:async token=>({uid:token})}};
try {
  await db.doc('appConfig/imageUsage').set({schemaVersion:1,policyRevision:imageUsagePolicyRevision,enabled:true,allowedProjectIds:[projectId]});
  await db.doc(`imageUsageAccounts/${ownerId}`).set({mode:'enrolled',policyPlan:'free',policyRevision:imageUsagePolicyRevision,
    revision:0,inventoryComplete:true,eligibility:{tokenFree:true,rulesReady:true},storageUsedBytes:0,storageReservedBytes:0,storageUnknownBytes:0});
  await db.doc(`subscriptionEntitlements/${ownerId}`).set({plan:'free',canStartClass:true,status:'active',validUntilMs:now+86400000});
  await realtime.ref(`users/${ownerId}`).set({uid:ownerId});
  const canvas=createCanvas(960,540),g=canvas.getContext('2d');
  g.fillStyle='#526b60';g.fillRect(0,0,960,540);g.fillStyle='#fffdf8';g.font='bold 90px sans-serif';g.fillText('HOME FIXTURE',30,260);
  const bytes=canvas.toBuffer('image/png'),sha256=hashBytes(bytes),assetId='home-image';
  const path=`users/${ownerId}/managed-images/workout/${assetId}/${sha256}`;
  await bucket.file(path).save(bytes,{resumable:false,metadata:{contentType:'image/png',metadata:{sha256}}});
  const [meta]=await bucket.file(path).getMetadata();
  const asset={assetId,ownerId,path,bucket:bucket.name,generation:String(meta.generation),sizeBytes:bytes.length,
    contentType:'image/png',sha256,tokenFree:true};asset.source=assetSource(ctx,assetId,asset.generation);
  await db.doc(`imageUsageAccounts/${ownerId}/assets/${assetId}`).set(asset);
  const lease=await handleMediaLease(ctx,{schemaVersion:1,action:'issue',requestId:'home_local_lease',assetIds:[assetId],
    admissionId:null,sessionId:null,purpose:'preview'},ownerId);
  const headers={Authorization:`Bearer ${ownerId}`,'X-CloudBoard-Media-Lease':lease.leaseId};
  let size;
  await serve(handleMedia,ctx,async url=>{
    const endpoint=`${url}?assetId=${assetId}&v=${asset.generation}&rendition=home-v1`;
    for(let i=0;i<2;i++){
      const result=await fetch(endpoint,{headers});assert.equal(result.status,200,await result.clone().text());
      const body=Buffer.from(await result.arrayBuffer());size=body.length;
      assert.ok(size<=65536);assert.equal(result.headers.get('content-type'),'image/jpeg');
    }
    assert.equal((await fetch(endpoint,{headers:{...headers,Authorization:'Bearer other-owner'}})).status,403);
  });
  let usage=await readUsage(ctx,{ownerId});
  assert.equal(usage.downloadDay.usedBytes,size*2);assert.equal(usage.downloadMonth.usedBytes,size*2);
  assert.equal(usage.downloadDay.reservedBytes,0);assert.equal(usage.downloadDay.unknownBytes,0);
  assert.equal(usage.uploadDay.usedBytes,0);assert.equal(usage.storage.usedBytes,0);
  const attempts=await db.collection(`imageUsageAccounts/${ownerId}/attempts`).get();
  assert.equal(attempts.size,2);assert.ok(attempts.docs.every(d=>d.data().sizeBytes===size&&d.data().rendition==='home-v1'));
  const admissions=await db.collection(`imageUsageAccounts/${ownerId}/admissions`).get();assert.equal(admissions.size,0);
  const base={ownerId,actorUid:ownerId,deviceId:null,leaseId:lease.leaseId,assetId,generation:asset.generation,
    admissionId:null,sessionId:null,purpose:'preview'};
  // Cannot mislabel a full original, forge smaller bills, or use rendition bytes
  // against the historical original contract.
  for(const extra of [{rendition:'home-v1',sizeBytes:bytes.length},{rendition:'home-v1',sizeBytes:size-1},
      {rendition:'other',sizeBytes:size},{sizeBytes:size}])await assert.rejects(reserveTransfer(ctx,{...base,...extra}));
  const manifest=(await homeThumbnailRef(ctx,asset).get()).data();assert.equal(manifest.status,'ready');assert.equal(manifest.attempts,1);
  // Generation mismatch and missing originals cannot resurrect a saved rendition.
  await db.doc(`imageUsageAccounts/${ownerId}/assets/${assetId}`).update({generation:'999'});
  await serve(handleMedia,ctx,async url=>assert.equal((await fetch(`${url}?assetId=${assetId}&v=${asset.generation}&rendition=home-v1`,{headers})).status,403));
  // Existing account cleanup owns both derived object and server-only manifest.
  await bucket.deleteFiles({prefix:`users/${ownerId}/`});
  await db.recursiveDelete(db.doc(`users/${ownerId}`));
  assert.equal((await homeThumbnailRef(ctx,asset).get()).exists,false);
  assert.equal((await bucket.file(homeThumbnailPath(asset)).exists())[0],false);
  const report={projectId,originalBytes:bytes.length,renditionBytes:size,httpRenditionRequests:2,originalClientGETs:0,
    downloadDayUsedBytes:usage.downloadDay.usedBytes,downloadMonthUsedBytes:usage.downloadMonth.usedBytes,
    reservationRemaining:0,admissions:0,thumbnailGenerationAttempts:1,accountCleanupVerified:true,
    auth:'injected local identity',externalServices:false};
  if(process.env.HOME_EVIDENCE)await writeFile(`${process.env.HOME_EVIDENCE}/emulator-byte-evidence.json`,JSON.stringify(report,null,2));
  console.log('PASS home rendition HTTP + actual ledger transactions, forged-size denial, revision denial and account cleanup',report);
} finally {await deleteApp(app);}
