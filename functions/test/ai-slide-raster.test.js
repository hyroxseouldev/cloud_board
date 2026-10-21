import test from 'node:test';
import assert from 'node:assert/strict';
import {RASTER_MODEL, RASTER_RESERVE, rasterHash, rasterCost, rasterPng,
  validateRasterDraft, requestRasterGroups, requestRasterArtwork} from '../src/ai-slide-raster-provider.js';

// Header-only bytes exercise the provider contract, not a decoder/quality claim.
const png = (width = 1536, height = 864) => {
  const bytes = Buffer.alloc(33);
  Buffer.from([137,80,78,71,13,10,26,10]).copy(bytes);
  bytes.write('IHDR', 12); bytes.writeUInt32BE(width,16); bytes.writeUInt32BE(height,20);
  return bytes;
};
const rawWod = '  TEAM OF 3\r\nRow 1,000 m\nDB Squat 22.5 kg × 12\n휴식 60초  ';
const lines = ['TEAM OF 3','Row 1,000 m','DB Squat 22.5 kg × 12','휴식 60초'];
const draft = {rawWod, title: '수요일 수업', brief: '3개 그룹, 글자를 작게', groups: [{heading:'A',lines}]};
const brand = {backgroundColor:'#fff8ee', textColor:'#242321', accentColor:'#da6138'};

test('draft keeps exact raw source, units and ordered groups; font is explicit', () => {
  const result = validateRasterDraft(draft);
  assert.equal(result.rawWod, rawWod);
  assert.deepEqual(result.groups[0].lines, lines);
  assert.equal(result.bodyFontSize,42);
  for (const bad of [lines.slice(1), [...lines].reverse(), lines.map(s=>s.replace('22.5','22'))]) {
    assert.throws(()=>validateRasterDraft({...draft,groups:[{heading:'A',lines:bad}]}), e=>e.details.reason==='changed-source');
  }
  assert.throws(()=>validateRasterDraft({...draft,bodyFontSize:8}), {code:'invalid-argument'});
});

test('Luna can return only contiguous line indices, never rewritten workout text', async () => {
  let payload;
  const reply = ends => async (url, request) => {
    assert.equal(url,'https://api.openai.com/v1/responses'); payload=JSON.parse(request.body);
    return {ok:true,json:async()=>({status:'completed',usage:{input_tokens:20,output_tokens:10},
      output:[{type:'message',content:[{type:'output_text',text:JSON.stringify({ends})}]}]})};
  };
  const result=await requestRasterGroups(draft,'not-a-key',reply([1,3,4]));
  assert.deepEqual(result.result.groups.flatMap(g=>g.lines),lines);
  assert.deepEqual(result.result.groups.map(g=>g.lines.length),[1,2,1]);
  assert.equal(payload.store,false);
  assert.equal(payload.text.format.schema.additionalProperties,false);
  for(const ends of [[1,3],[2,1,4],[0,4],[1,2,3,4]]) {
    await assert.rejects(requestRasterGroups(draft,'not-a-key',reply(ends)),e=>e.details.reason==='group-coverage');
  }
});

test('actual edits request is explicit one-image artwork; exact logo stays out of model', async () => {
  const reference=png(1672,941),previous=png(); let calls=0;
  const result=await requestRasterArtwork({reference,previous,draft,brand,uid:'local-fixture'},'not-a-key',async(url,request)=>{
    calls++; assert.equal(url,'https://api.openai.com/v1/images/edits');
    const form=request.body;
    assert.equal(form.get('model'),RASTER_MODEL); assert.equal(form.get('size'),'1536x864');
    assert.equal(form.get('n'),'1'); assert.equal(form.get('quality'),'medium');
    assert.equal(form.get('output_format'),'png'); assert.equal(form.getAll('image[]').length,2);
    assert.deepEqual(Buffer.from(await form.getAll('image[]')[0].arrayBuffer()),reference);
    assert.match(form.get('prompt'),/Do not draw any text or logo/);
    assert.match(form.get('prompt'),/#fff8ee/); assert.match(form.get('prompt'),/No timer circle or digits/);
    assert.equal(form.get('safety_identifier'),rasterHash('local-fixture'));
    return {ok:true,json:async()=>({data:[{b64_json:png().toString('base64')}],
      usage:{input_tokens:110,input_tokens_details:{text_tokens:10,image_tokens:100},output_tokens:200}})};
  });
  assert.equal(calls,1); assert.equal(result.costMicros,6850);
  assert.equal(result.costBasis,'provider-usage'); assert.equal(result.width/result.height,16/9);
});

test('image usage has a separate conservative reservation and rejects unsafe responses', async () => {
  assert.equal(rasterCost({}).costMicros,RASTER_RESERVE);
  assert.equal(rasterCost({input_tokens:0,input_tokens_details:{text_tokens:1,image_tokens:2},output_tokens:4}).costBasis,'reservation-retained');
  const args={reference:png(),draft,brand,uid:'local'};
  for(const status of [400,401,429,500,408]) {
    await assert.rejects(requestRasterArtwork(args,'not-a-key',async()=>({ok:false,status})),
      e=>e.details.reason===(status>=500||status===408?'provider-uncertain':'provider-rejected'));
  }
  await assert.rejects(requestRasterArtwork(args,'not-a-key',async()=>{throw Error('socket closed');}),e=>e.details.reason==='provider-uncertain');
  await assert.rejects(requestRasterArtwork(args,'not-a-key',async()=>({ok:true,json:async()=>({data:[{b64_json:png(1024,1024).toString('base64')}]})})),{code:'data-loss'});
  assert.throws(()=>rasterPng(png(),{width:1536,height:864,sha256:'wrong'}),{code:'data-loss'});
});
