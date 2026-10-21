import test from 'node:test';
import assert from 'node:assert/strict';
import {createCanvas,loadImage} from '@napi-rs/canvas';
import {requestTemplateImage,templateImagePrompt} from '../src/template-image.js';
import {rasterHash,RASTER_MODEL} from '../src/ai-slide-raster-provider.js';

const source={uid:'owner',recipe:{templateId:'sweatmonday-numbered-v1'},title:'TODAY’S WORKOUT',
  subtitle:'4mins 30s On / 1min Off',rawWod:'Bird Dog+\nSquat To Stand\nInchworm With Push-Up\nA-Skip\nKnee Up\nSync Jump Lunge 20',background:Buffer.from('reference')};
const usage={input_tokens:120,input_tokens_details:{text_tokens:20,image_tokens:100},output_tokens:200,
  output_tokens_details:{image_tokens:200}};
function png(width=2048,height=1152){const canvas=createCanvas(width,height),ctx=canvas.getContext('2d');
  ctx.fillStyle='#ff6600';ctx.fillRect(0,0,width,height);return canvas.toBuffer('image/png');}

test('image edit receives reference and every source string, and only resolution is normalized',async()=>{
  const generated=png();let payload;
  const result=await requestTemplateImage(source,'test',async(url,options)=>{
    assert.equal(url,'https://api.openai.com/v1/images/edits');payload=options.body;
    return {ok:true,json:async()=>({data:[{b64_json:generated.toString('base64')}],usage})};
  });
  assert.equal(payload.get('model'),RASTER_MODEL);assert.equal(payload.get('quality'),'high');
  assert.equal(payload.get('size'),'2048x1152');assert.equal(payload.get('safety_identifier'),rasterHash(source.uid));
  assert.deepEqual(Buffer.from(await payload.get('image[]').arrayBuffer()),source.background);
  const prompt=payload.get('prompt');
  assert.ok(prompt.includes(JSON.stringify({title:source.title,time:source.subtitle,body:source.rawWod.split('\n')})));
  assert.match(prompt,/ONE left-aligned vertical column/);assert.match(prompt,/COMPLETE image/);
  assert.equal(result.width,1920);assert.equal(result.height,1080);assert.equal(result.costMicros,6900);
  const image=await loadImage(result.bytes),canvas=createCanvas(1920,1080),ctx=canvas.getContext('2d');
  ctx.drawImage(image,0,0);assert.deepEqual([...ctx.getImageData(1000,600,1,1).data],[255,102,0,255]);
});
test('existing A/B/C templates keep their reference layout instead of receiving numbered-list instructions',()=>{
  const prompt=templateImagePrompt({...source,recipe:{templateId:'sweatmonday-team-of-3-v1'}});
  assert.match(prompt,/one column per section/);assert.doesNotMatch(prompt,/ONE left-aligned vertical column/);
});
test('ambiguous provider failures are not presented as safe to generate again',async()=>{
  for(const fetchImpl of [async()=>{throw Error('network');},async()=>({ok:false,status:503}),
    async()=>({ok:true,json:async()=>{throw Error('broken response');}})]){
    await assert.rejects(requestTemplateImage(source,'test',fetchImpl),e=>e.details.reason==='provider-uncertain');
  }
  await assert.rejects(requestTemplateImage(source,'test',async()=>({ok:false,status:429})),e=>e.details.reason==='provider-rejected');
});
test('known invalid image retains actual provider billing and rejects missing or wrong-size results',async()=>{
  for(const data of [[],[{b64_json:png(1024,1024).toString('base64')}],[{b64_json:'invalid'}]]){
    await assert.rejects(requestTemplateImage(source,'test',async()=>({ok:true,json:async()=>({data,usage})})),
      e=>e.details.reason==='provider-invalid-image'&&e.details.providerBilling.costMicros===6900);
  }
});
