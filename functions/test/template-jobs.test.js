import test from 'node:test';
import assert from 'node:assert/strict';
import {createCanvas} from '@napi-rs/canvas';
import {handleTemplateJobs, processTemplateJob} from '../src/template-jobs.js';
import {rasterHash, rasterFail} from '../src/ai-slide-raster-provider.js';
import {aiTimerMonth} from '../src/ai-timer.js';
import {renderTemplate, validateLayout, requestTemplateLayout} from '../src/template-layout.js';

// Transaction double for crash/concurrency states; not described as E2E.
class MemoryDb {
  rows = new Map(); queue = Promise.resolve();
  doc(path) { return {path, get: async () => this.snap(path)}; }
  snap(path) { const value = this.rows.get(path); return {exists: value !== undefined, data: () => structuredClone(value)}; }
  async getAll(...refs) { return refs.map(r => this.snap(r.path)); }
  runTransaction(callback) {
    const run = this.queue.then(async () => {
      const writes = [];
      const result = await callback({get: async r => this.snap(r.path), getAll: (...r) => this.getAll(...r),
        set: (r, v, o) => writes.push(() => this.rows.set(r.path, o?.merge ? {...this.rows.get(r.path), ...v} : v)),
        delete: r => writes.push(() => this.rows.delete(r.path))});
      writes.forEach(f => f()); return result;
    });
    this.queue = run.catch(() => {}); return run;
  }
}
const uid = 'owner', centerId = 'test-center', now = Date.parse('2026-10-21T02:00:00Z');
const path = id => `users/${uid}/templateGenerationCenters/${centerId}/jobs/${id}`;
const usagePath = `users/${uid}/aiSlidesUsage/${aiTimerMonth(now).id}`;
const field = (binding, x, y, width, height, extra = {}) => ({binding, x, y, width, height,
  fontSize: 44, color: 0xff111111, fontFamily: 'Pretendard', fontWeight: 700, ...extra});
function setup() {
  const db = new MemoryDb(), canvas = createCanvas(1920,1080), ctx = canvas.getContext('2d');
  ctx.fillStyle = '#faf6ed'; ctx.fillRect(0,0,1920,1080);
  ctx.fillStyle = '#f60'; ctx.fillRect(1400,30,200,80); // Immutable logo evidence.
  const bytes = canvas.toBuffer('image/png'), sha = rasterHash(bytes);
  const recipe = {schemaVersion: 1, centerId, templateId: 'test-template', revision: 1,
    width: 1920, height: 1080, backgroundColor: 0xfffaf6ed,
    backgroundPath: `center-templates/${centerId}/test-template/${sha}.png`, backgroundSha256: sha,
    fields: [field('title',.04,.05,.56,.1), field('subtitle',.04,.20,.56,.08),
      field('line',.04,.4,.56,.08,{lineIndex:0})]};
  const files = new Map([[recipe.backgroundPath, bytes]]); let uploads = 0;
  const bucket = {file: p => ({getMetadata: async () => [{size: files.get(p)?.length, contentType:'image/png'}],
    download: async () => [files.get(p)], save: async b => { uploads++; files.set(p,b); },
    delete: async () => files.delete(p)})};
  db.rows.set(`centers/${centerId}`, {ownerUid: uid});
  db.rows.set(`users/${uid}/onboarding/progress`, {storeId: centerId});
  db.rows.set(`subscriptionEntitlements/${uid}`, {plan:'premium',status:'active',policyVersion:'plan-entitlements-v2', validUntilMs:now+86400000});
  db.rows.set(`centers/${centerId}/slideTemplateCatalog/current`, {revision:1,templates:[{id:recipe.templateId,published:true,recipe}]});
  const input = {action:'enqueue',centerId,requestId:'request-1',title:'10월 21일',subtitle:'',rawWod:'Run 800m\nSki 500m · DB Press 12회',
    design:{id:'center-template',name:'센터',theme:{centerRecipe:recipe}}};
  let calls = 0;
  const generate = async () => { calls++; return {layout:{columns:1,ends:[2],headings:[1]},costMicros:50,usage:{input:100,output:75}}; };
  const options = {db,bucket,uid,apiKey:'test-only',clock:()=>now};
  return {db,bucket,files,input,options,recipe,bytes,generate,calls:()=>calls,uploads:()=>uploads};
}
test('accept returns pending, duplicate acceptance charges once, basic templates never reserve AI', async () => {
  const s = setup();
  const a = await handleTemplateJobs({...s.options,input:s.input});
  assert.equal(a.job.status,'pending'); assert.equal(s.calls(),0); assert.equal(s.uploads(),0);
  await handleTemplateJobs({...s.options,input:s.input}); assert.equal(s.db.rows.get(usagePath).used,1);
  await assert.rejects(handleTemplateJobs({...s.options,input:{...s.input,rawWod:'changed'}}),{code:'already-exists'});
  await assert.rejects(handleTemplateJobs({...s.options,input:{...s.input,requestId:'basic',design:{id:'basic',name:'기본',theme:{}}}}), e=>e.details.reason==='basic-template-no-ai');
  assert.equal(s.db.rows.get(usagePath).used,1);
});
test('duplicate event execution yields one provider call, complete only after persisted PNG, private asset recovers', async () => {
  const s=setup(); await handleTemplateJobs({...s.options,input:s.input});
  let resolve, notify; const started=new Promise(r=>notify=r);
  const generate=async () => { notify(); await new Promise(r=>resolve=r); return s.generate(); };
  const first=processTemplateJob({...s.options,...s.input,generate}); await started;
  assert.equal(s.db.rows.get(path(s.input.requestId)).status,'processing');
  await processTemplateJob({...s.options,...s.input,generate});
  resolve(); await first;
  await processTemplateJob({...s.options,...s.input,generate});
  assert.equal(s.calls(),1); assert.equal(s.uploads(),1); assert.equal(s.db.rows.get(usagePath).used,1);
  const j=s.db.rows.get(path(s.input.requestId)); assert.equal(j.status,'complete');
  const image=await handleTemplateJobs({...s.options,input:{...s.input,action:'asset'}});
  assert.equal(rasterHash(Buffer.from(image.base64,'base64')),j.artifact.sha256);
});
test('crashed external call becomes uncertain failure and never starts another provider operation', async () => {
  const s=setup(); await handleTemplateJobs({...s.options,input:s.input});
  Object.assign(s.db.rows.get(path(s.input.requestId)),{status:'processing',stage:'provider',leaseUntilMs:now-1});
  await processTemplateJob({...s.options,...s.input,generate:s.generate});
  const j=s.db.rows.get(path(s.input.requestId));
  assert.equal(s.calls(),0); assert.equal(j.status,'failed'); assert.equal(j.retryable,false); assert.equal(j.quotaCharged,true);
});
test('saved layout recovers failed upload without another AI call or charge', async () => {
  const s=setup(); await handleTemplateJobs({...s.options,input:s.input});
  let attempts=0; const original=s.bucket.file;
  s.bucket.file=p=>({...original(p),save:async b=>{ if(++attempts===1) throw Error('storage unavailable'); return original(p).save(b); }});
  await processTemplateJob({...s.options,...s.input,generate:s.generate});
  assert.equal(s.db.rows.get(path(s.input.requestId)).stage,'render');
  await processTemplateJob({...s.options,...s.input,generate:s.generate});
  assert.equal(s.calls(),1); assert.equal(s.db.rows.get(path(s.input.requestId)).status,'complete'); assert.equal(s.db.rows.get(usagePath).used,1);
});
test('late fenced worker cleanup cannot delete the replacement worker complete image', async () => {
  const s=setup(); await handleTemplateJobs({...s.options,input:s.input});
  let unlock, notify, renders=0; const started=new Promise(r=>notify=r);
  const render=async input=>{ if(++renders===1) {notify();await new Promise(r=>unlock=r);} return renderTemplate(input); };
  const first=processTemplateJob({...s.options,...s.input,generate:s.generate,render});await started;
  await processTemplateJob({...s.options,...s.input,clock:()=>now+180001,generate:s.generate,render});
  const complete=s.db.rows.get(path(s.input.requestId));assert.equal(complete.status,'complete');
  unlock();await first;
  assert.ok(s.files.has(complete.artifact.path));assert.equal(s.calls(),1);
  assert.equal([...s.files.keys()].filter(p=>p.startsWith('users/')).length,1);
});
test('definite rejection refunds, retry consumes once, lost retry acceptance response remains recoverable', async () => {
  const s=setup(); await handleTemplateJobs({...s.options,input:s.input});
  await processTemplateJob({...s.options,...s.input,generate:async()=>{throw rasterFail('unavailable','거절','provider-rejected');}});
  assert.equal(s.db.rows.get(usagePath).used,0);
  const retry={action:'enqueue',centerId,requestId:'request-2',retryOf:s.input.requestId};
  const options={...s.options,clock:()=>now+6000};
  await handleTemplateJobs({...options,input:retry});
  await handleTemplateJobs({...options,input:retry});
  assert.equal(s.db.rows.get(usagePath).used,1);
  await assert.rejects(handleTemplateJobs({...options,input:{...retry,requestId:'request-3'}}));
});
test('ownership/account change blocks reading and completing, removes uploaded orphan', async () => {
  const s=setup(); await handleTemplateJobs({...s.options,input:s.input});
  const original=s.bucket.file;
  s.bucket.file=p=>({...original(p),save:async b=>{await original(p).save(b);s.db.rows.set(`accountDeletions/${uid}`,{});}});
  await processTemplateJob({...s.options,...s.input,generate:s.generate});
  const j=s.db.rows.get(path(s.input.requestId)); assert.equal(j.status,'failed'); assert.equal(j.artifact,null);
  assert.equal([...s.files.keys()].filter(p=>p.startsWith('users/')).length,0);
  await assert.rejects(handleTemplateJobs({...s.options,input:{...s.input,action:'status'}}),{code:'permission-denied'});
});
test('layout cannot drop/reorder lines; compositor retains exact source, header and timer blank area', async () => {
  const s=setup(), lines=s.input.rawWod.split('\n');
  assert.throws(()=>validateLayout({columns:1,ends:[1],headings:[]},lines));
  const result=await renderTemplate({...s.input,recipe:s.recipe,background:s.bytes,layout:{columns:1,ends:[2],headings:[1]}});
  assert.deepEqual(result.evidence.lines.filter(x=>x.binding==='line').map(x=>x.text),lines);
  assert.ok(result.evidence.lines.every(x=>x.x+x.width<=1260));
  const {loadImage}=await import('@napi-rs/canvas');
  const image=await loadImage(result.bytes),c=createCanvas(1920,1080),ctx=c.getContext('2d');ctx.drawImage(image,0,0);
  assert.deepEqual([...ctx.getImageData(1450,50,1,1).data],[255,102,0,255]);
  assert.deepEqual([...ctx.getImageData(1600,700,1,1).data],[250,246,237,255]);
});
test('Luna receives source IDs and frozen style, never accepts generated replacement strings', async () => {
  const s=setup(); let payload;
  const result=await requestTemplateLayout({...s.input,recipe:s.recipe},'test-key',async(_url,opts)=>{
    payload=JSON.parse(opts.body);return {ok:true,json:async()=>({status:'completed',output:[{type:'message',content:[{type:'output_text',text:'{"columns":1,"ends":[2],"headings":[1]}'}]}],usage:{input_tokens:20,output_tokens:10}})};
  });
  assert.equal(payload.model,'gpt-6-luna');assert.equal(payload.store,false);
  assert.deepEqual(JSON.parse(payload.input).lines.map(x=>x.text),s.input.rawWod.split('\n'));
  assert.deepEqual(result.layout.ends,[2]);
});
