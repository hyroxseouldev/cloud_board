import test from 'node:test';
import assert from 'node:assert/strict';
import {Readable} from 'node:stream';
import {createCanvas} from '@napi-rs/canvas';
import {fixture,serve} from './media-gateway-fixtures.js';
import {handleMedia} from '../src/media-gateway.js';
import {hashBytes} from '../src/managed-image-assets.js';
import {legacyHomePath,legacyHomeRequest,resolveLegacyHomeAsset} from '../src/legacy-home-image.js';
import {HOME_INPUT_BYTES,HOME_MAX_PIXELS,homeImageDimensions,homeThumbnailPath,homeThumbnailRef} from '../src/home-image-thumbnail.js';

function artwork(width=3840,height=2160,type='image/png') {
  const canvas=createCanvas(width,height),g=canvas.getContext('2d');
  const gradient=g.createLinearGradient(0,0,width,height);
  gradient.addColorStop(0,'#264c43');gradient.addColorStop(1,'#d3dcc3');
  g.fillStyle=gradient;g.fillRect(0,0,width,height);
  g.fillStyle='#fffdf8';g.font='bold 220px sans-serif';g.fillText('MOVE TOGETHER',100,height/2);
  const bytes=canvas.toBuffer(type);canvas.width=1;canvas.height=1;return bytes;
}
const bytes4k=artwork();
const smallBytes=artwork(960,540);
function setup({historical=false,bytes=smallBytes}={}) {
  const s=fixture(bytes),factory=s.ctx.bucket.file;
  s.ctx.bucket.file=(path,options)=>({...factory(path,options),createReadStream:()=>{
    s.events.push(['stream',path,options]);
    return Readable.from((async function*(){
      if(s.beforeStream)await s.beforeStream(path);
      const item=s.files.get(path);if(!item)throw Object.assign(Error('deleted'),{code:404});
      yield item.bytes;
    })());
  },delete:async()=>{s.events.push(['delete',path]);s.files.delete(path);}});
  const path=`users/owner/workouts/original-class/${historical?'modules/slide-one/background':`images/${'a'.repeat(64)}`}`;
  const source=`https://firebasestorage.googleapis.com/v0/b/${s.ctx.bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=legacy-token`;
  s.files.set(path,{bytes,metadata:{generation:'11',size:bytes.length,contentType:'image/png',metadata:{firebaseStorageDownloadTokens:'legacy-token'}}});
  s.path=path;s.source=source;
  s.input={workoutId:'copied-class',sourceHash:hashBytes(source),updatedAtMs:123456};
  s.db.rows.set('users/owner/workouts/copied-class',{id:'copied-class',ownerId:'owner',author:{id:'owner'},updatedAt:123456,modules:[{imageUrl:source}]});
  s.db.rows.set('users/owner/workoutSummaries/copied-class',{id:'copied-class',imageSource:source,updatedAt:123456});
  s.query=()=>`?${new URLSearchParams({rendition:'home-v1',...s.input,updatedAtMs:String(s.input.updatedAtMs)})}`;
  return s;
}
const headers={Authorization:'Bearer owner'};
const request=(s,fn)=>serve(handleMedia,s.ctx,url=>fn(`${url}${s.query()}`));

test('legacy 4K cold GET is real small JPEG, reused by copied class, with no lease/enrollment/original mutation',async()=>{
  for(const historical of [false,true]){
    const s=setup({historical,bytes:bytes4k}),before={bytes:Buffer.from(s.files.get(s.path).bytes),metadata:structuredClone(s.files.get(s.path).metadata)};let body;
    await request(s,async url=>{
      const coldHead=await fetch(url,{headers,method:'HEAD'});assert.equal(coldHead.status,404);
      for(let i=0;i<2;i++){
        const r=await fetch(url,{headers});assert.equal(r.status,200,await r.clone().text());
        body=Buffer.from(await r.arrayBuffer());assert.equal(r.headers.get('content-type'),'image/jpeg');
        assert.ok(body.length<=65536);assert.deepEqual(homeImageDimensions(body,'image/jpeg'),{width:192,height:108});
      }
      const head=await fetch(url,{headers,method:'HEAD'});assert.equal(head.status,200);assert.equal(Number(head.headers.get('content-length')),body.length);
    });
    assert.equal(s.events.filter(e=>e[0]==='stream'&&e[1]===s.path).length,1);
    assert.equal(s.events.filter(e=>e[0]==='download').length,0);
    assert.equal(s.events.filter(e=>e[0]==='save').length,1);
    assert.deepEqual(s.files.get(s.path),before);
    assert.equal([...s.db.rows.keys()].filter(p=>p.startsWith('imageUsageMediaLeases/')).length,0);
    for(const [,value] of s.events.filter(e=>e[0]==='reserveTransfer')){
      assert.equal(value.sizeBytes,body.length);assert.equal(value.leaseId,null);
      assert.equal(value.admissionId,null);assert.equal(value.sessionId,null);assert.equal(value.legacyHome.kind,'legacy-home');
    }
  }
});

test('strict query and authoritative ownership/source/revision reject before any original read',async()=>{
  for(const mode of ['other','anonymous','revoked','tv','missing','summary','revision','firstSource','owner','deleted','enrolled','enrolling','pending']){
    const s=setup();let h=headers;
    if(mode==='other')h={Authorization:'Bearer other'};
    if(mode==='revoked')h={Authorization:'Bearer revoked'};
    if(mode==='anonymous')s.ctx.auth.verifyIdToken=async()=>({uid:'owner',firebase:{sign_in_provider:'anonymous'}});
    if(mode==='tv')s.ctx.actorBindings={owner:{ownerId:'controller',deviceId:'tv'}};
    if(mode==='missing')s.db.rows.delete('users/owner/workouts/copied-class');
    if(mode==='summary')s.db.rows.get('users/owner/workoutSummaries/copied-class').imageSource='https://other.test/a';
    if(mode==='revision')s.db.rows.get('users/owner/workouts/copied-class').updatedAt++;
    if(mode==='firstSource')s.db.rows.get('users/owner/workouts/copied-class').modules[0].imageUrl='';
    if(mode==='owner')s.db.rows.get('users/owner/workouts/copied-class').ownerId='other';
    if(mode==='deleted')s.db.rows.set('accountDeletions/owner',{});
    if(['enrolled','enrolling','pending'].includes(mode))s.db.rows.set('imageUsageAccounts/owner',{mode:mode==='pending'?'legacy':mode,enrollmentPending:mode==='pending'});
    await request(s,async url=>assert.ok((await fetch(url,{headers:h})).status>=400,mode));
    assert.equal(s.events.filter(e=>e[0]==='stream').length,0,mode);
  }
  const s=setup(),q={rendition:'home-v1',...s.input,updatedAtMs:String(s.input.updatedAtMs)};
  for(const bad of [{...q,url:s.source},{...q,assetId:'image-one'},{...q,sourceHash:'A'.repeat(64)},
    {...q,updatedAtMs:'01'},{...q,updatedAtMs:'Infinity'},{...q,updatedAtMs:'253402300800000'},
    {...q,workoutId:'../other'},{...q,workoutId:['copied-class']},{...q,rendition:'original'}])assert.throws(()=>legacyHomeRequest(bad));
});

test('exact bucket and the two historical namespaces only; source token never grants access',()=>{
  const s=setup();assert.equal(legacyHomePath(s.ctx,'owner',s.source),s.path);
  const url=path=>`https://firebasestorage.googleapis.com/v0/b/${s.ctx.bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=anything`;
  for(const path of ['users/other/workouts/a/images/'+'a'.repeat(64),'users/owner/profile/photo',
    'users/owner/brand/logo','users/owner/support/request/file','users/owner/managed-images/workout/file',
    'users/owner/ai-slide-raster/a/b/file.png','users/owner/workouts/a/../images/'+'a'.repeat(64),
    'users/owner/workouts/a/images/file.jpg','users/owner/workouts/a/modules/m/other'])assert.equal(legacyHomePath(s.ctx,'owner',url(path)),null,path);
  for(const source of [s.source.replace(s.ctx.bucket.name,'other.appspot.com'),s.source+'#fragment',
    s.source+'&url=http://169.254.169.254',s.source+'&token=duplicate','https://other.test/file',
    s.source.replace('https://','http://')])assert.equal(legacyHomePath(s.ctx,'owner',source),null);
});

test('post-I/O checks deny source edits, deleted source, replacement generation, enrollment and revocation; no image handoff',async()=>{
  for(const mode of ['summary','workout','generation','sourceDeleted','account','enrollment','revoked']){
    const s=setup();await request(s,async url=>assert.equal((await fetch(url,{headers})).status,200));
    const asset=await resolveLegacyHomeAsset(s.ctx,'owner',s.input);
    s.beforeStream=path=>{
      if(path!==homeThumbnailPath(asset))return;
      if(mode==='summary')s.db.rows.get('users/owner/workoutSummaries/copied-class').updatedAt++;
      if(mode==='workout')s.db.rows.delete('users/owner/workouts/copied-class');
      if(mode==='generation')s.files.get(s.path).metadata.generation='12';
      if(mode==='sourceDeleted')s.files.delete(s.path);
      if(mode==='account')s.db.rows.set('accountDeletions/owner',{});
      if(mode==='enrollment')s.db.rows.set('imageUsageAccounts/owner',{mode:'enrolling'});
      if(mode==='revoked')s.ctx.auth.verifyIdToken=async()=>{throw Error('revoked');};
    };
    await request(s,async url=>assert.ok((await fetch(url,{headers})).status>=400,mode));
    const settled=s.events.filter(e=>e[0]==='settleTransfer').at(-1)[1];assert.equal(settled.outcome,'not_sent');assert.equal(settled.bodyBytes,0);
  }
});

test('new current generation uses new claim; concurrent cold requests decode once; temporary claims recover boundedly',async()=>{
  const s=setup();await request(s,async url=>{
    const results=await Promise.all([fetch(url,{headers}),fetch(url,{headers})]);
    assert.deepEqual(results.map(r=>r.status).sort(),[200,404]);
  });
  const old=await resolveLegacyHomeAsset(s.ctx,'owner',s.input);
  assert.equal((await homeThumbnailRef(s.ctx,old).get()).data().attempts,1);
  s.files.get(s.path).metadata.generation='12';
  await request(s,async url=>assert.equal((await fetch(url,{headers})).status,200));
  assert.equal(s.events.filter(e=>e[0]==='stream'&&e[1]===s.path).length,2);
  const fresh=await resolveLegacyHomeAsset(s.ctx,'owner',s.input);assert.notEqual(homeThumbnailPath(old),homeThumbnailPath(fresh));
  const failing=setup();let n=0;failing.beforeStream=()=>{n++;throw Error('temporary');};
  for(let i=0;i<3;i++)await request(failing,async url=>assert.equal((await fetch(url,{headers})).status,404));
  assert.equal(n,2);
  const crashed=setup(),crashedAsset=await resolveLegacyHomeAsset(crashed.ctx,'owner',crashed.input);
  const ref=homeThumbnailRef(crashed.ctx,crashedAsset);
  crashed.db.rows.set(ref.path,{status:'pending',claim:'lost-worker',attempts:1,expiresAtMs:61000});
  await request(crashed,async url=>assert.equal((await fetch(url,{headers})).status,404));
  assert.equal(crashed.events.filter(e=>e[0]==='stream').length,0);
  crashed.ctx.clock=()=>61001;
  await request(crashed,async url=>assert.equal((await fetch(url,{headers})).status,200));
  assert.equal(crashed.db.rows.get(ref.path).attempts,2);
});

test('account lock racing a derivative save removes the late private object and never returns ready',async()=>{
  const s=setup(),factory=s.ctx.bucket.file;
  s.ctx.bucket.file=(path,options)=>{
    const file=factory(path,options);
    return {...file,save:async(bytes,metadata)=>{
      await file.save(bytes,metadata);s.db.rows.set('accountDeletions/owner',{status:'processing'});
    }};
  };
  await request(s,async url=>assert.equal((await fetch(url,{headers})).status,404));
  assert.equal(s.events.filter(e=>e[0]==='delete').length,1);
  assert.ok([...s.files.keys()].every(p=>!p.includes('/home-v1/')));
  assert.equal(s.events.filter(e=>e[0]==='reserveTransfer').length,0);
});

test('10MiB metadata/stream and 16Mi-pixel header caps, unsupported types, and budget have bounded fallback',async()=>{
  const s=setup();assert.ok(homeImageDimensions(bytes4k,'image/png'));
  const over=Buffer.from(bytes4k);over.writeUInt32BE(8192,16);over.writeUInt32BE(8192,20);
  assert.equal(homeImageDimensions(over,'image/png'),null);assert.equal(HOME_MAX_PIXELS,16777216);
  for(const mutation of [m=>m.size=HOME_INPUT_BYTES+1,m=>m.contentType='image/webp',m=>m.contentEncoding='gzip']){
    const f=setup();mutation(f.files.get(f.path).metadata);
    await request(f,async url=>assert.equal((await fetch(url,{headers})).status,404));
    assert.equal(f.events.filter(e=>e[0]==='stream').length,0);
  }
  const bad=setup({bytes:over});await request(bad,async url=>assert.equal((await fetch(url,{headers})).status,404));
  assert.equal(bad.events.filter(e=>e[0]==='save').length,0);
  s.ctx.denyReserve=true;await request(s,async url=>assert.equal((await fetch(url,{headers})).status,429));
  assert.equal(s.events.filter(e=>e[0]==='settleTransfer').length,0);
});
