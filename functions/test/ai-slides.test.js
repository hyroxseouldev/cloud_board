import {createHash} from 'node:crypto';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readSlidePrompt, validateSlides, requestAiSlides, handleAiSlides, slidesSchema} from '../src/ai-slides.js';

const result = {complete: true, slides: [{title: 'WARM UP', layout: 'numbered', sourceTitleLineIds: [1],
  sections: [{heading: '', lines: ['스쿼트 10회', 'Lunge 12 reps'], sourceLineIds: [2, 3, 4]}],
  workSeconds: 300, restSeconds: 0, sets: 1}], warnings: []};
const source = readSlidePrompt({prompt: 'WARM UP\n스쿼트 10회\nLunge 12 reps\n5분, 휴식 없음, 1세트'});
const expected = {...result, slides: [{...result.slides[0], lines: result.slides[0].sections[0].lines}]};
const withSlide = change => ({...result, slides: [{...result.slides[0], ...change}]});
const withLines = lines => withSlide({sections: [{heading: '', lines, sourceLineIds: [2, 3, 4]}]});
const reason = name => error => error.code === 'data-loss' && error.details.reason === name;

test('slide prompts are bounded, normalized and content-addressed with stable source IDs', () => {
  for (const prompt of [null, '', '   ', 'x'.repeat(6001)]) assert.throws(() => readSlidePrompt({prompt}), {code:'invalid-argument'});
  assert.deepEqual(readSlidePrompt({prompt:' Squat\r\n10 reps '}), readSlidePrompt({prompt:'Squat\n10 reps'}));
  assert.deepEqual(readSlidePrompt({prompt:' TITLE\n \n Squat 10 reps \n'}).sourceLines, ['TITLE', 'Squat 10 reps']);
  assert.notEqual(readSlidePrompt({prompt:'Squat'}).key, readSlidePrompt({prompt:'Lunge'}).key);
});
test('slide validator preserves sections, missing timings and units while deriving legacy flat lines', () => {
  const missing = withSlide({workSeconds:null, restSeconds:null, sets:null});
  assert.deepEqual(validateSlides(missing), {...expected, slides:[{...expected.slides[0],workSeconds:null,restSeconds:null,sets:null}]});
  assert.deepEqual(validateSlides(result, source), expected);
  assert.deepEqual(validateSlides({...result, slides:[{...result.slides[0],lines:['malicious stale flat result']}]}), expected);
  assert.throws(() => validateSlides({...result,complete:false}), reason('incomplete-content'));
  for (const change of [{layout:'javascript'}, {sections:[]}, {sections:undefined},
    {sections:[{heading:'MAIN\nOTHER',lines:['RUN'],sourceLineIds:[1]}]},
    {sections:[{heading:'',lines:['x'.repeat(121)],sourceLineIds:[1]}]},
    {sourceTitleLineIds:[0]}, {sourceTitleLineIds:[1,1]}, {sourceTitleLineIds:[4,1]},
    {sections:[{heading:'',lines:['RUN'],sourceLineIds:[]}]},
    {title:''}, {title:'title\nnew line'}, {sets:0}, {workSeconds:3601}, {restSeconds:-1}, {sets:1.5}, {sets:undefined}]) {
    assert.throws(() => validateSlides(withSlide(change)), {code:'data-loss'});
  }
  for (const slides of [[],Array(2).fill(result.slides[0])]) assert.throws(() => validateSlides({...result,slides}), {code:'data-loss'});
});
test('section headings count toward the single-slide capacity and are flattened in source order', () => {
  const sections = [{heading:'WARM UP',lines:['Squat 10 reps'],sourceLineIds:[1,2]},
    {heading:'MAIN',lines:['Run 1km'],sourceLineIds:[3,4]}];
  assert.deepEqual(validateSlides(withSlide({title:'TODAY',sourceTitleLineIds:[],sections})).slides[0].lines,
    ['WARM UP','Squat 10 reps','MAIN','Run 1km']);
  const lines=Array.from({length:24},(_,i)=>`${i+1}. RUN ${i+1}km`);
  assert.deepEqual(validateSlides(withLines(lines)).slides[0].lines,lines);
  assert.throws(() => validateSlides(withLines([...lines, 'extra'])), {code:'data-loss'});
  assert.throws(() => validateSlides(withSlide({sections:[{heading:'MAIN',lines,sourceLineIds:[1]}]})), reason('invalid-content'));
});
test('empty untimed or heading-only output is rejected but explicit pure intervals are supported', () => {
  assert.throws(() => validateSlides(withLines([])), reason('invalid-content'));
  assert.throws(() => validateSlides(withSlide({layout:'interval',workSeconds:null,
    sections:[{heading:'MAIN',lines:[],sourceLineIds:[1]}]})), reason('invalid-content'));
  const timerOnly = withSlide({title:'INTERVAL',sourceTitleLineIds:[],layout:'interval',workSeconds:40,restSeconds:20,sets:3,
    sections:[{heading:'',lines:[],sourceLineIds:[1]}]});
  assert.deepEqual(validateSlides(timerOnly,readSlidePrompt({prompt:'40 seconds work / 20 seconds rest / 3 rounds'})).slides[0].lines,[]);
});
test('every nonempty source line must be accounted for and fabricated IDs are rejected', () => {
  assert.throws(() => validateSlides(withSlide({sections:[{...result.slides[0].sections[0],sourceLineIds:[2,3]}]}),source), reason('missing-source-content'));
  assert.throws(() => validateSlides(withSlide({sourceTitleLineIds:[1,9]}),source), reason('missing-source-content'));
  // Provenance IDs do not prove semantic accuracy. A claimed ID still cannot
  // conceal a dropped/changed explicit measurement in the deterministic guard.
  assert.throws(() => validateSlides(withLines(['스쿼트 10회']),source), reason('changed-source-quantity'));
  assert.throws(() => validateSlides(withLines(['스쿼트 8회','Lunge 12 reps']),source), reason('changed-source-quantity'));
  assert.throws(() => validateSlides(withLines(['스쿼트 10','Lunge 12']),source), reason('changed-source-quantity'));
});
test('quantity guard preserves repeated measurements, ranges and weights without treating list numbers as reps', () => {
  const check = (original, generated) => validateSlides(withSlide({sourceTitleLineIds:[],workSeconds:null,restSeconds:null,sets:null,
    sections:[{heading:'',lines:[generated],sourceLineIds:[1]}]}),readSlidePrompt({prompt:original}));
  assert.doesNotThrow(() => check('1. Run 1km', 'Run 1000m'));
  assert.doesNotThrow(() => check('2) Row 1,000m', 'Row 1000m'));
  assert.doesNotThrow(() => check('3. Hold 1 min 30 sec', 'Hold 90 seconds'));
  assert.doesNotThrow(() => check('4. Hold 01:30', 'Hold 90초'));
  assert.doesNotThrow(() => check('5. Squat 10–12 reps / 20kg', 'Squat 10-12회 / 20kg'));
  assert.doesNotThrow(() => check('1. 930 ad', '930 ad'));
  assert.throws(() => check('Run 1km / Row 1km', 'Run 1km / Row'), reason('changed-source-quantity'));
  assert.throws(() => check('Squat 10-12 reps / 20kg', 'Squat 8-12 reps / 20kg'), reason('changed-source-quantity'));
  assert.throws(() => check('Squat 10 reps / 20kg', 'Squat 10 reps / 20'), reason('changed-source-quantity'));
});
test('Luna organizes indexed source notes using strict sections schema and bounded output', async () => {
  const output = await requestAiSlides(source, 'test-only', async (url, options) => {
    assert.equal(url,'https://api.openai.com/v1/responses');
    const body = JSON.parse(options.body);
    assert.equal(body.model,'gpt-6-luna'); assert.equal(body.store,false);
    assert.equal(body.max_output_tokens,5000); assert.equal(body.text.format.strict,true);
    assert.deepEqual(JSON.parse(body.input[0].content[0].text),source.sourceLines.map((text,index)=>({id:index+1,text})));
    assert.match(body.instructions,/untrusted/); assert.match(body.instructions,/MUST be null/);
    assert.match(body.instructions,/EXACTLY ONE slide/);
    assert.match(body.instructions,/keep ALL their explicit timing details/);
    assert.equal(body.text.format.schema.properties.slides.maxItems,1);
    assert.equal(body.text.format.schema.properties.slides.items.properties.sections.maxItems,24);
    return {ok:true,json:async()=>({status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(result)}]}],
      usage:{input_tokens:2000,output_tokens:500}})};
  });
  assert.deepEqual(output,{result:expected,costMicros:500});
});
test('provider output claiming complete with missing source content is rejected', async () => {
  await assert.rejects(requestAiSlides(source,'test',async()=>({ok:true,json:async()=>({status:'completed',output:[
    {type:'message',content:[{type:'output_text',text:JSON.stringify(withLines(['스쿼트 10회']))}]}]})})),reason('changed-source-quantity'));
});
test('refusals, incomplete results and upstream errors do not expose provider data', async () => {
  const prompt=readSlidePrompt({prompt:'notes'});
  for (const response of [
    {ok:false,status:500,json:async()=>{throw new Error('do not read provider body');}},
    {ok:true,json:async()=>({status:'incomplete'})},
    {ok:true,json:async()=>({status:'completed',output:[{type:'message',content:[{type:'refusal',refusal:'private'}]}]})},
  ]) await assert.rejects(requestAiSlides(prompt,'test',async()=>response), error => !error.message.includes('private'));
  await assert.rejects(handleAiSlides({uid:null}), {code:'unauthenticated'});
});
test('old flat-result cache cannot bypass new section and source validation', () => {
  assert.equal(slidesSchema.properties.slides.items.properties.sections.maxItems,24);
  const prompt='WARM UP and MAIN';
  for (const version of ['stationd-v1','stationd-v2-single-slide']) {
    const oldKey=createHash('sha256').update(`${version}/gpt-6-luna/${prompt}`).digest('hex');
    assert.notEqual(readSlidePrompt({prompt}).key,oldKey);
  }
});
