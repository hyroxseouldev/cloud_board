import {createServer} from 'node:http';
import {once} from 'node:events';
import {randomUUID} from 'node:crypto';
import {assetSource,hashBytes,usageFailure} from '../src/managed-image-assets.js';
export class MemoryDb {
  rows=new Map();queue=Promise.resolve();
  doc(path) { return {path,get:async()=>this.snap(path),collection:child=>({doc:id=>this.doc(`${path}/${child}/${id}`)})}; }
  snap(path) {const value=this.rows.get(path);return {exists:value!==undefined,data:()=>structuredClone(value)};}
  async getAll(...refs) {return refs.map(r=>this.snap(r.path));}
  runTransaction(fn) {const p=this.queue.then(async()=>{const writes=[];const result=await fn({get:async r=>this.snap(r.path),getAll:(...r)=>this.getAll(...r),set:(r,v,o)=>writes.push(()=>this.rows.set(r.path,structuredClone(o?.merge?{...this.rows.get(r.path),...v}:v)))});writes.forEach(f=>f());return result;});this.queue=p.catch(()=>{});return p;}
}
export function png(size=40) {const b=Buffer.alloc(size,17);Buffer.from([137,80,78,71,13,10,26,10]).copy(b);b.write('IHDR',12);b.writeUInt32BE(100,16);b.writeUInt32BE(100,20);return b;}
export function fixture(bytes=png()) {
  const db=new MemoryDb(),files=new Map(),events=[];
  const ctx={db,projectId:'demo-image-usage',emulator:true,mediaBaseUrl:'http://127.0.0.1:5001/demo-image-usage/asia-northeast3/cloudboardMedia',allowedOrigins:['http://localhost:5173'],clock:()=>1000,
    auth:{verifyIdToken:async(token,revoked)=>{events.push(['auth',revoked]);if(token==='revoked')throw Error('revoked');return {uid:token};}}};
  ctx.bucket={name:'demo-image-usage.appspot.com',file:(path,opts)=>({
    getMetadata:async()=>{events.push(['metadata',path,opts]);const o=files.get(path);if(!o)throw Object.assign(Error('missing'),{code:404});return [{...o.metadata}];},
    download:async()=>{events.push(['download',path,opts]);return [files.get(path).bytes];},
    save:async(b,options)=>{events.push(['save',path,options]);if(files.has(path))throw Object.assign(Error('exists'),{code:412});files.set(path,{bytes:b,metadata:{...options.metadata,size:b.length,generation:'8'}});},
  })};
  const records=()=>[...db.rows.values()].filter(v=>v.uploadId);
  ctx.ledger={
    requireUsageContext:async(_ctx,value)=>{events.push(['context',value]);if(ctx.denyActor)throw usageFailure('media_lease_invalid','permission-denied');const b=ctx.actorBindings?.[value.actorUid];return {ownerId:b?.ownerId??value.ownerId??value.actorUid,actorUid:value.actorUid,deviceId:b?.deviceId??null,deviceBinding:b?.deviceBinding??null,allowedAssetSources:ctx.previewSources??[],mode:'enrolled'};},
    reserveTransfer:async(_ctx,args)=>{events.push(['reserveTransfer',args]);if(ctx.denyReserve)throw usageFailure('daily_transfer_limit','resource-exhausted');return {attemptId:randomUUID()};},
    settleTransfer:async(_ctx,args)=>{events.push(['settleTransfer',args]);},
    reserveUpload:async(_ctx,args)=>{events.push(['reserveUpload',args]);let old=records().find(r=>r.requestId===args.requestId);if(old)return old;const uploadId=randomUUID();const r={...args,uploadId,path:`users/${args.ownerId}/managed-images/${args.purpose}/${uploadId}/${args.sha256??'pending'}`,status:'reserved',asset:null,expiresAtMs:301000};db.rows.set(`imageUsageAccounts/${args.ownerId}/uploads/${uploadId}`,r);return r;},
    beginUpload:async(_ctx,args)=>{events.push(['beginUpload',args]);const r=records().find(r=>r.uploadId===args.uploadId);if(r.status!=='reserved')throw usageFailure('upload_mismatch');r.status='writing';return r;},
    bindGeneratedUpload:async(_ctx,args)=>{events.push(['bindGeneratedUpload',args]);const r=records().find(r=>r.uploadId===args.uploadId);r.boundOutput={sha256:args.sha256,sizeBytes:args.sizeBytes};r.path=`users/${r.ownerId}/managed-images/generated/${r.uploadId}/${args.sha256}`;return r;},
    settleUpload:async(_ctx,args)=>{events.push(['settleUpload',args]);const r=records().find(r=>r.uploadId===args.uploadId);r.status=args.outcome==='stored'?'stored':args.outcome==='unknown'?'unknown':'cancelled';r.asset=args.asset;if(args.asset)_ctx.db.rows.set(`imageUsageAccounts/${args.ownerId}/assets/${args.asset.assetId}`,args.asset);return r;},
  };
  const asset={assetId:'image-one',ownerId:'owner',path:'users/owner/managed-images/workout/image-one/sha',generation:'7',sizeBytes:bytes.length,contentType:'image/png',sha256:hashBytes(bytes),bucket:ctx.bucket.name,tokenFree:true};
  asset.source=assetSource(ctx,asset.assetId,asset.generation);
  db.rows.set('imageUsageAccounts/owner/assets/image-one',asset);
  files.set(asset.path,{bytes,metadata:{generation:'7',size:bytes.length,contentType:'image/png',metadata:{sha256:asset.sha256}}});
  return {ctx,db,files,events,asset,bytes};
}
export async function serve(handler,ctx,fn) {
  const server=createServer(async(req,res)=>{
    req.query=Object.fromEntries(new URL(req.url,'http://localhost').searchParams);
    if(req.method==='POST'){const chunks=[];for await(const c of req)chunks.push(c);req.rawBody=Buffer.concat(chunks);}
    await handler(ctx,req,res);
  });server.listen(0,'127.0.0.1');await once(server,'listening');
  try{return await fn(`http://127.0.0.1:${server.address().port}`);}finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
}
