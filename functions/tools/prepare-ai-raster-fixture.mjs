// Local files by default. Explicit --seed-local only targets the dedicated demo
// project on pinned loopback emulators. No OpenAI request or external deployment.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {rasterPng} from '../src/ai-slide-raster-provider.js';

export const localRasterFixture = Object.freeze({projectId:'demo-cloudboard-studio',uid:'studio-preview',centerId:'studio-preview-center',
  auth:'127.0.0.1:19499',firestore:'127.0.0.1:19480',database:'127.0.0.1:19400',storage:'127.0.0.1:19419'});
const templateId='raster-approved-sweatmonday';
export function assertLocalRasterEnvironment(env=process.env) {
  for(const [name,value] of Object.entries({GCLOUD_PROJECT:localRasterFixture.projectId,
    FIREBASE_AUTH_EMULATOR_HOST:localRasterFixture.auth,FIRESTORE_EMULATOR_HOST:localRasterFixture.firestore,
    FIREBASE_DATABASE_EMULATOR_HOST:localRasterFixture.database,FIREBASE_STORAGE_EMULATOR_HOST:localRasterFixture.storage})) {
    assert.equal(env[name],value,`Refusing non-local or unpinned ${name}`);
  }
  assert.ok(!env.GOOGLE_APPLICATION_CREDENTIALS,'External credentials are not allowed');
  assert.ok(!env.FIREBASE_CONFIG || JSON.parse(env.FIREBASE_CONFIG).projectId===localRasterFixture.projectId,'External Firebase config is not allowed');
}
export async function prepareRasterFixture({catalogPath,referencePath,logoPath,output}) {
  const catalog=JSON.parse(await fs.readFile(catalogPath,'utf8'));
  const original=catalog.templates.find(t=>t.id==='sweatmonday-team-of-3-v1');
  assert.ok(original?.published && original.recipe,'Approved SWEATMONDAY entry required');
  const reference=await fs.readFile(referencePath),logo=await fs.readFile(logoPath);
  const referenceInfo=rasterPng(reference),logoInfo=rasterPng(logo);
  assert.equal(referenceInfo.sha256,'4b9be3ae2b21c933b507f8cf9b79451df96fdbfb98ba7d25c6836fada714b511','Wrong approved original');
  assert.equal(logoInfo.sha256,'5c2cdb00a423dc650cd44e1b473a50d921d1e515caf6408f3e8c37367ee2ac72','Wrong official logo pixels');
  const {uid,centerId}=localRasterFixture;
  const referenceAsset={...referenceInfo,path:`center-templates/${centerId}/${templateId}/${referenceInfo.sha256}.png`};
  const logoAsset={...logoInfo,path:`users/${uid}/brand/raster-official-${logoInfo.sha256}.png`,sourceRect:[535,300,615,265]};
  const recipe={...original.recipe,centerId,templateId,backgroundPath:referenceAsset.path,backgroundSha256:referenceInfo.sha256};
  // Optional thumbnail is deliberately omitted: the copied reference is the
  // approved original, not a derived background/thumb from a different recipe.
  delete recipe.thumbnail;
  const template={...original,id:templateId,recipe};
  const brand={schemaVersion:1,enabled:true,revision:1,catalogRevision:1,recipeRevision:recipe.revision,
    templateId,name:'SWEATMONDAY · 로컬 확인',reference:referenceAsset,logo:logoAsset,
    backgroundColor:'#f4efe5',textColor:'#2d302b',accentColor:'#a8b691',fixtureOwner:'sta202-raster'};
  await fs.mkdir(path.dirname(path.resolve(output)),{recursive:true});
  await fs.mkdir(output,{mode:0o700}); // Never overwrite a previous bundle.
  await fs.writeFile(path.join(output,'reference.png'),reference,{mode:0o600,flag:'wx'});
  await fs.writeFile(path.join(output,'logo.png'),logo,{mode:0o600,flag:'wx'});
  await fs.writeFile(path.join(output,'fixture.json'),JSON.stringify({schemaVersion:1,local:localRasterFixture,template,brand},null,2)+'\n',{mode:0o600,flag:'wx'});
  return {output:path.resolve(output),referenceSha:referenceInfo.sha256,logoSha:logoInfo.sha256};
}
export async function seedRasterFixture(directory) {
  assertLocalRasterEnvironment();
  const fixture=JSON.parse(await fs.readFile(path.join(directory,'fixture.json'),'utf8'));
  assert.deepEqual(fixture.local,localRasterFixture);
  const {brand,template}=fixture,{uid,centerId,projectId}=localRasterFixture;
  assert.equal(brand.templateId,templateId);assert.equal(template.id,templateId);
  const reference=await fs.readFile(path.join(directory,'reference.png')),logo=await fs.readFile(path.join(directory,'logo.png'));
  rasterPng(reference,brand.reference);rasterPng(logo,brand.logo);
  assert.equal(brand.reference.path,`center-templates/${centerId}/${templateId}/${brand.reference.sha256}.png`);
  assert.equal(brand.logo.path,`users/${uid}/brand/raster-official-${brand.logo.sha256}.png`);
  const {initializeApp,deleteApp}=await import('firebase-admin/app');
  const {getFirestore}=await import('firebase-admin/firestore');
  const {getAuth}=await import('firebase-admin/auth');
  const {getStorage}=await import('firebase-admin/storage');
  const app=initializeApp({projectId,storageBucket:`${projectId}.appspot.com`},`raster-fixture-${Date.now()}`);
  try {
    const db=getFirestore(app),auth=getAuth(app),bucket=getStorage(app).bucket();
    // Existing user/workout data is never replaced. If a different fixture owns
    // the identity or center, stop before writing rather than moving it.
    const refs=[`centers/${centerId}`,`users/${uid}/onboarding/progress`,`subscriptionEntitlements/${uid}`,
      `centers/${centerId}/slideTemplateCatalog/current`,`centers/${centerId}/aiSlideBrand/current`].map(p=>db.doc(p));
    const [center,onboarding,grant,catalog,configured]=await db.getAll(...refs);
    assert.ok(!center.exists||center.data().ownerUid===uid,'Center already owned by another local fixture');
    assert.ok(!onboarding.exists||onboarding.data().storeId===centerId,'Do not overwrite onboarding');
    assert.ok(!grant.exists||(grant.data().plan==='premium'&&grant.data().validUntilMs>Date.now()),'Existing local entitlement needs coordinator review; never overwrite');
    assert.ok(!configured.exists||configured.data().fixtureOwner==='sta202-raster','Brand config already owned elsewhere');
    let user;
    try {user=await auth.getUser(uid);} catch(error) {if(error.code!=='auth/user-not-found') throw error;}
    assert.ok(!user||user.email==='studio-preview@example.test','Do not overwrite a different local identity');
    if(!user) await auth.createUser({uid,email:'studio-preview@example.test',emailVerified:true,password:'local-preview-only'});
    for(const [asset,bytes] of [[brand.reference,reference],[brand.logo,logo]]) {
      const file=bucket.file(asset.path),[exists]=await file.exists();
      if(exists) {const [old]=await file.download();rasterPng(old,asset);}
      else await file.save(bytes,{resumable:false,preconditionOpts:{ifGenerationMatch:0},metadata:{contentType:'image/png',cacheControl:'private, no-store'}});
    }
    await db.runTransaction(async tx=>{
      const [latestCenter,latestOnboarding,latestGrant,latestCatalog,latestBrand]=await tx.getAll(...refs);
      assert.ok(!latestCenter.exists||latestCenter.data().ownerUid===uid);
      assert.ok(!latestOnboarding.exists||latestOnboarding.data().storeId===centerId);
      assert.ok(!latestBrand.exists||latestBrand.data().fixtureOwner==='sta202-raster');
      const entries=latestCatalog.data()?.templates??[];
      const existing=entries.find(t=>t.id===templateId);
      if(existing) assert.deepEqual(existing,template,'Do not overwrite an edited local catalog entry');
      const revision=(latestCatalog.data()?.revision??0)+(existing?0:1);
      if(!latestCenter.exists) tx.create(refs[0],{ownerUid:uid,name:'로컬 미리보기 센터'});
      if(!latestOnboarding.exists) tx.create(refs[1],{storeId:centerId,completed:true});
      if(!latestGrant.exists) tx.create(refs[2],{plan:'premium',status:'active',validUntilMs:Date.now()+7*86400000});
      if(!existing) tx.set(refs[3],{...(latestCatalog.data()??{}),centerId,centerName:'로컬 미리보기 센터',revision,templates:[...entries,template]});
      tx.set(refs[4],{...brand,catalogRevision:revision});
    });
    return {projectId,templateId,brandRevision:brand.revision,openAiCalls:0};
  } finally {await deleteApp(app);}
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const args=process.argv.slice(2);
  if(args[0]==='--seed-local'&&args.length===2) console.log(JSON.stringify(await seedRasterFixture(args[1])));
  else {
    const options=Object.fromEntries(Array.from({length:args.length/2},(_,i)=>[args[i*2],args[i*2+1]]));
    assert.ok(options['--catalog']&&options['--reference']&&options['--logo']&&options['--output'],
      'Usage: --catalog FILE --reference PNG --logo PNG --output NEW_PRIVATE_DIRECTORY | --seed-local DIRECTORY');
    console.log(JSON.stringify(await prepareRasterFixture({catalogPath:options['--catalog'],referencePath:options['--reference'],logoPath:options['--logo'],output:options['--output']})));
  }
}
