import {test} from 'node:test';
import assert from 'node:assert/strict';
import {aiTimerMonth, isAiTimerPremium, readAiTimerImage, validateAiTimerResult, requestAiTimer, handleAiTimer} from '../src/ai-timer.js';

const valid = {multipleTimers: false, name: 'Squat', workSeconds: 30, restSeconds: 15, sets: 4, warnings: []};
function png(w = 1024, h = 768) {
  const b = Buffer.alloc(24); Buffer.from([137,80,78,71,13,10,26,10]).copy(b);
  b.write('IHDR', 12); b.writeUInt32BE(w, 16); b.writeUInt32BE(h, 20); return b.toString('base64');
}
test('AI gate trusts only unexpired premium, including premium trials, not client flags', () => {
  const now=1000;
  for (const plan of ['free', 'plus', 'legacy', undefined]) assert.equal(isAiTimerPremium({plan, status:'active', validUntilMs:2000}, now), false);
  for (const status of ['active','trialing','grace_period']) assert.equal(isAiTimerPremium({plan:'premium',status,validUntilMs:2000}, now), true);
  assert.equal(isAiTimerPremium({plan:'premium',status:'revoked',validUntilMs:2000}, now), false);
  assert.equal(isAiTimerPremium({plan:'premium',status:'active',validUntilMs:1000}, now), false);
});
test('quota month changes at Korean midnight, including year rollover', () => {
  assert.equal(aiTimerMonth(Date.parse('2026-10-31T14:59:59Z')).id, '2026-10');
  assert.equal(aiTimerMonth(Date.parse('2026-10-31T15:00:00Z')).id, '2026-11');
  assert.equal(new Date(aiTimerMonth(Date.parse('2026-12-10T00:00:00Z')).resetsAtMs).toISOString(), '2026-12-31T15:00:00.000Z');
});
test('image validation bounds payload and dimensions, never fetches client URLs', () => {
  const image = readAiTimerImage({imageBase64:png()});
  assert.equal(image.mime, 'image/png');
  assert.equal(image.key, readAiTimerImage({imageBase64:png()}).key);
  assert.throws(() => readAiTimerImage({imageBase64:png(20000)}), {code:'invalid-argument'});
  for (const imageBase64 of ['https://localhost/admin','a===','A'.repeat(6*1024*1024),'junk']) {
    assert.throws(() => readAiTimerImage({imageBase64}), {code:'invalid-argument'});
  }
  assert.doesNotThrow(() => readAiTimerImage({imageBase64:Buffer.concat([Buffer.from(png(),'base64'),Buffer.alloc(2*1024*1024)]).toString('base64')}));
  assert.throws(() => readAiTimerImage({imageBase64:Buffer.from([255,216,...Array(100).fill(255)]).toString('base64')}), {code:'invalid-argument'});
});
test('missing values remain null; invalid or fractional timings are rejected', () => {
  const multiple = validateAiTimerResult({...valid,multipleTimers:true});
  assert.equal(multiple.workSeconds,null); assert.equal(multiple.restSeconds,null); assert.equal(multiple.sets,null);
  assert.deepEqual(validateAiTimerResult({...valid,workSeconds:null,restSeconds:null,sets:null}), {...valid,workSeconds:null,restSeconds:null,sets:null});
  for (const delta of [{workSeconds:0},{restSeconds:-1},{sets:1.5},{sets:101},{workSeconds:'30'},{workSeconds:undefined},{warnings:['x'.repeat(251)]}]) {
    assert.throws(() => validateAiTimerResult({...valid,...delta}), {code:'data-loss'});
  }
});
test('provider request uses one image, strict output, no storage; parses and counts usage', async () => {
  const result = await requestAiTimer(readAiTimerImage({imageBase64:png()}), 'test-only', async (url, options) => {
    assert.equal(url, 'https://api.openai.com/v1/responses');
    const request = JSON.parse(options.body);
    assert.equal(request.store, false); assert.equal(request.reasoning.effort, 'none');
    assert.equal(request.text.format.strict,true); assert.equal(request.max_output_tokens,1000);
    return {ok:true,json:async()=>({status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(valid)}]}],usage:{input_tokens:3000,output_tokens:300}})};
  });
  assert.deepEqual(result.result,valid); assert.equal(result.costMicros,525);
});
test('errors and incomplete responses never expose provider bodies', async () => {
  const image=readAiTimerImage({imageBase64:png()});
  await assert.rejects(requestAiTimer(image,'test',async()=>({ok:false,status:429,json:async()=>{throw new Error('body-must-not-be-read');}})), {code:'unavailable'});
  await assert.rejects(requestAiTimer(image,'test',async()=>({ok:true,json:async()=>({status:'incomplete',output:[]})})), {code:'data-loss'});
  await assert.rejects(handleAiTimer({db:null,uid:null,input:{action:'analyze'}}), {code:'unauthenticated'});
});
