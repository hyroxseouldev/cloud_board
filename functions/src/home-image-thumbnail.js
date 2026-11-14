// Optional private, image-only home rendition. Never fetch a client URL.
import {randomUUID} from 'node:crypto';
import {accountPath, hashBytes, managedMetadata} from './managed-image-assets.js';

export const HOME_RENDITION = 'home-v1';
export const HOME_MAX_BYTES = 64 * 1024;
export const HOME_INPUT_BYTES = 2 * 1024 * 1024;
const MAX_PIXELS = 4 * 1024 * 1024;
let decoding = false;
export const homeThumbnailId = asset => `${asset.assetId}-${asset.generation}`;
export const homeThumbnailPath = asset =>
  `users/${asset.ownerId}/managed-images/home-v1/${asset.assetId}/${asset.generation}.jpg`;
export const homeThumbnailRef = (ctx, asset) =>
  ctx.db.doc(`users/${asset.ownerId}/homeThumbnails/${homeThumbnailId(asset)}`);

// Inspect dimensions/animation BEFORE the native decoder allocates pixels.
export function homeImageDimensions(bytes, type) {
  if (!Buffer.isBuffer(bytes) || !bytes.length || bytes.length > HOME_INPUT_BYTES) return null;
  let width, height;
  if (type === 'image/png') {
    if (bytes.length < 33 || !bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])) ||
        bytes.toString('ascii',12,16) !== 'IHDR' || bytes.readUInt32BE(8) !== 13) return null;
    width=bytes.readUInt32BE(16); height=bytes.readUInt32BE(20);
    let end=false;
    for (let pos=8; pos+12<=bytes.length;) {
      const length=bytes.readUInt32BE(pos), tag=bytes.toString('ascii',pos+4,pos+8);
      if (length > bytes.length-pos-12 || tag === 'acTL' || tag==='IHDR' && pos!==8) return null;
      pos+=length+12;
      if (tag==='IEND') { end=pos===bytes.length; break; }
    }
    if (!end) return null;
  } else if (type === 'image/jpeg') {
    if (bytes[0]!==255 || bytes[1]!==216 || bytes.at(-2)!==255 || bytes.at(-1)!==217) return null;
    for (let pos=2; pos+4<=bytes.length;) {
      if (bytes[pos++]!==255) return null;
      while(bytes[pos]===255) pos++;
      const marker=bytes[pos++];
      if (pos+2>bytes.length) return null;
      if (marker===0xda || marker===0xd9) break;
      const length=bytes.readUInt16BE(pos);
      if (length<2 || pos+length>bytes.length) return null;
      if ([0xc0,0xc1,0xc2].includes(marker)) {
        if (width!==undefined || length<8 || bytes[pos+2]!==8) return null;
        height=bytes.readUInt16BE(pos+3); width=bytes.readUInt16BE(pos+5);
      }
      // Other JPEG frame/precision modes are outside this bounded contract.
      if (marker>=0xc0 && marker<=0xcf && ![0xc0,0xc1,0xc2,0xc4,0xc8,0xcc].includes(marker)) return null;
      pos+=length;
    }
  } else return null; // GIF/WebP/animated inputs retain neutral placeholders.
  return width>0 && height>0 && width<=8192 && height<=8192 && width*height<=MAX_PIXELS
    ? {width,height} : null;
}
export async function renderHomeThumbnail(bytes, type) {
  const dimensions=homeImageDimensions(bytes,type);
  if (!dimensions) return null;
  const {loadImage, createCanvas}=await import('@napi-rs/canvas');
  const image=await loadImage(bytes);
  if (image.width*image.height>MAX_PIXELS) return null;
  const scale=Math.min(1,192/Math.max(image.width,image.height));
  const canvas=createCanvas(Math.max(1,Math.round(image.width*scale)),Math.max(1,Math.round(image.height*scale)));
  const context=canvas.getContext('2d');
  context.fillStyle='#fffdf8'; context.fillRect(0,0,canvas.width,canvas.height);
  context.drawImage(image,0,0,canvas.width,canvas.height);
  const body=await canvas.encode('jpeg',72);
  return body.length<=HOME_MAX_BYTES ? {body,width:canvas.width,height:canvas.height} : null;
}
export function validHomeThumbnail(value, asset) {
  return value?.status==='ready' && value.rendition===HOME_RENDITION &&
    value.ownerId===asset.ownerId && value.assetId===asset.assetId &&
    value.originalGeneration===asset.generation && value.originalSha256===asset.sha256 &&
    value.path===homeThumbnailPath(asset) && /^[0-9]+$/.test(value.generation) &&
    /^[a-f0-9]{64}$/.test(value.sha256) && Number.isSafeInteger(value.sizeBytes) &&
    value.sizeBytes>0 && value.sizeBytes<=HOME_MAX_BYTES && value.contentType==='image/jpeg' &&
    Number.isInteger(value.width) && value.width>0 && value.width<=192 &&
    Number.isInteger(value.height) && value.height>0 && value.height<=192;
}
async function boundedRead(file, limit) {
  const stream=file.createReadStream({decompress:false, validation:'crc32c'});
  const deadline=setTimeout(()=>stream.destroy(Error('home-image-timeout')),10000);
  const parts=[]; let size=0;
  try {
    for await (const chunk of stream) {
      size+=chunk.length;
      if (size>limit) throw Error('home-image-byte-limit');
      parts.push(chunk);
    }
    return Buffer.concat(parts,size);
  } finally { clearTimeout(deadline); stream.destroy(); }
}
export async function readHomeThumbnail(ctx, asset, value) {
  if (!validHomeThumbnail(value,asset)) throw Error('invalid-home-thumbnail');
  const file=ctx.bucket.file(value.path,{generation:value.generation});
  const [meta]=await file.getMetadata();
  if (String(meta.generation)!==value.generation || Number(meta.size)!==value.sizeBytes ||
      meta.contentType!==value.contentType || meta.contentEncoding && meta.contentEncoding!=='identity' ||
      meta.metadata?.firebaseStorageDownloadTokens || meta.metadata?.sha256!==value.sha256 ||
      meta.metadata?.originalSha256!==asset.sha256) throw Error('invalid-home-thumbnail-metadata');
  const bytes=await boundedRead(file,HOME_MAX_BYTES);
  if (bytes.length!==value.sizeBytes || hashBytes(bytes)!==value.sha256) throw Error('invalid-home-thumbnail-body');
  return bytes;
}

// Upload bytes can be reused. Cold generation gets at most two bounded attempts
// per immutable revision; expired claims recover after 60s, never an endless retry.
export async function ensureHomeThumbnail(ctx,asset,uploadBytes=null) {
  const ref=homeThumbnailRef(ctx,asset), prior=(await ref.get()).data();
  if (validHomeThumbnail(prior,asset)) return prior;
  if (decoding || !['image/png','image/jpeg'].includes(asset.contentType) ||
      asset.sizeBytes>HOME_INPUT_BYTES) return null;
  decoding=true;
  const claim=randomUUID(), now=(ctx.clock??Date.now)();
  try {
    const claimed=await ctx.db.runTransaction(async tx=>{
      const old=(await tx.get(ref)).data();
      const deleting=await tx.get(ctx.db.doc(`accountDeletions/${asset.ownerId}`));
      const current=(await tx.get(ctx.db.doc(accountPath(asset.ownerId,'assets',asset.assetId)))).data();
      if (deleting.exists || current?.generation!==asset.generation || current?.sha256!==asset.sha256) return false;
      if (validHomeThumbnail(old,asset) || old?.status==='unsupported' ||
          old?.attempts>=2 || old?.status==='pending' && old.expiresAtMs>now) return false;
      tx.set(ref,{status:'pending',claim,attempts:(old?.attempts??0)+1,expiresAtMs:now+60000});
      return true;
    });
    if (!claimed) return null;
    const finish=async result=>ctx.db.runTransaction(async tx=>{
      const old=(await tx.get(ref)).data();
      const deleting=await tx.get(ctx.db.doc(`accountDeletions/${asset.ownerId}`));
      if (!deleting.exists && old?.claim===claim) tx.set(ref,{...old,...result,expiresAtMs:0});
    });
    try {
      let bytes=uploadBytes;
      if (!bytes) { const {file}=await managedMetadata(ctx,asset); bytes=await boundedRead(file,HOME_INPUT_BYTES); }
      if (bytes.length!==asset.sizeBytes || hashBytes(bytes)!==asset.sha256) throw Error('home-original-mismatch');
      const rendered=await renderHomeThumbnail(bytes,asset.contentType);
      if (!rendered) { await finish({status:'unsupported'}); return null; }
      const [deleting,current]=await Promise.all([
        ctx.db.doc(`accountDeletions/${asset.ownerId}`).get(),
        ctx.db.doc(accountPath(asset.ownerId,'assets',asset.assetId)).get(),
      ]);
      if (deleting.exists || current.data()?.generation!==asset.generation || current.data()?.sha256!==asset.sha256) return null;
      const {body,width,height}=rendered, path=homeThumbnailPath(asset), sha256=hashBytes(body);
      const file=ctx.bucket.file(path);
      try {
        await file.save(body,{resumable:false,preconditionOpts:{ifGenerationMatch:0},
          metadata:{contentType:'image/jpeg',cacheControl:'private,no-store',
            metadata:{sha256,originalSha256:asset.sha256,ownerId:asset.ownerId,rendition:HOME_RENDITION}}});
      } catch(error) { if (Number(error.code)!==412) throw error; }
      const [meta]=await file.getMetadata();
      const value={status:'ready',rendition:HOME_RENDITION,ownerId:asset.ownerId,assetId:asset.assetId,
        originalGeneration:asset.generation,originalSha256:asset.sha256,path,generation:String(meta.generation),
        sizeBytes:Number(meta.size),sha256:meta.metadata?.sha256,contentType:'image/jpeg',width,height};
      // A previous create may have committed before a timeout. Validate its
      // immutable metadata rather than overwrite any object on retry.
      if (!validHomeThumbnail(value,asset) || meta.contentType!=='image/jpeg' ||
          meta.metadata?.originalSha256!==asset.sha256 || meta.metadata?.firebaseStorageDownloadTokens) throw Error('home-object-mismatch');
      if ((await ctx.db.doc(`accountDeletions/${asset.ownerId}`).get()).exists) {
        await ctx.bucket.file(path,{generation:value.generation}).delete({ignoreNotFound:true});
        return null;
      }
      await finish(value); return value;
    } catch (_) { await finish({status:'failed'}); return null; }
  } finally { decoding=false; }
}
