import {createHash} from 'node:crypto';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readSlidePrompt, validateSlides, requestAiSlides, handleAiSlides, slidesSchema} from '../src/ai-slides.js';

const result = {complete: true, slides: [{title: 'WARM UP', layout: 'numbered', lines: ['스쿼트 10회', 'Lunge 12 reps'],
  workSeconds: 300, restSeconds: 0, sets: 1}], warnings: []};

test('slide prompts are bounded, normalized and content-addressed', () => {
  for (const prompt of [null, '', '   ', 'x'.repeat(6001)]) assert.throws(() => readSlidePrompt({prompt}), {code:'invalid-argument'});
  assert.deepEqual(readSlidePrompt({prompt:' Squat\r\n10 reps '}), readSlidePrompt({prompt:'Squat\n10 reps'}));
  assert.notEqual(readSlidePrompt({prompt:'Squat'}).key, readSlidePrompt({prompt:'Lunge'}).key);
});
test('slide validator preserves missing timings and exercise units and rejects malformed output', () => {
  const missing = {...result, slides:[{...result.slides[0], workSeconds:null, restSeconds:null, sets:null}]};
  assert.deepEqual(validateSlides(missing), missing);
  assert.throws(() => validateSlides({...result,complete:false}), error => error.details.reason === 'incomplete-content');
  for (const change of [{layout:'javascript'}, {lines:['x'.repeat(121)]}, {lines:Array(25).fill('x')},
    {title:''}, {title:'title\nnew line'}, {sets:0}, {workSeconds:3601}, {restSeconds:-1}, {sets:1.5}, {sets:undefined}]) {
    assert.throws(() => validateSlides({...result,slides:[{...result.slides[0],...change}]}), {code:'data-loss'});
  }
  for (const slides of [[],Array(2).fill(result.slides[0])]) assert.throws(() => validateSlides({...result,slides}), {code:'data-loss'});
});
test('Luna organizes notes using strict schema, no image generation/storage, and bounded output', async () => {
  const prompt = 'WARM UP: 스쿼트 10회. 5분, 휴식 없음, 1세트';
  const output = await requestAiSlides(readSlidePrompt({prompt}), 'test-only', async (url, options) => {
    assert.equal(url,'https://api.openai.com/v1/responses');
    const body = JSON.parse(options.body);
    assert.equal(body.model,'gpt-6-luna'); assert.equal(body.store,false);
    assert.equal(body.max_output_tokens,5000); assert.equal(body.text.format.strict,true);
    assert.equal(body.input[0].content[0].text,prompt);
    assert.match(body.instructions,/untrusted/); assert.match(body.instructions,/MUST be null/);
    assert.match(body.instructions,/EXACTLY ONE slide/);
    assert.match(body.instructions,/keep ALL their explicit timing details/);
    assert.equal(body.text.format.schema.properties.slides.maxItems,1);
    return {ok:true,json:async()=>({status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(result)}]}],
      usage:{input_tokens:2000,output_tokens:500}})};
  });
  assert.deepEqual(output,{result,costMicros:500});
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

test('long lessons remain on one slide and cannot reuse old multi-slide cache', () => {
  const lines=Array.from({length:24},(_,i)=>`${i+1}. RUN ${i+1}km`);
  assert.deepEqual(validateSlides({...result,slides:[{...result.slides[0],lines}]}).slides[0].lines,lines);
  assert.equal(slidesSchema.properties.slides.items.properties.lines.maxItems,24);
  const prompt='WARM UP and MAIN';
  const oldKey=createHash('sha256').update(`stationd-v1/gpt-6-luna/${prompt}`).digest('hex');
  assert.notEqual(readSlidePrompt({prompt}).key,oldKey);
});
