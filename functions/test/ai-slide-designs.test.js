import {test} from 'node:test';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {readSlideDesignPrompt, slideDesignSchema, validateSlideDesigns, requestAiSlideDesigns,
  handleAiSlideDesigns, REFERENCE_DESIGN_WARNING, normalizeProviderSlideDesigns, designColorContrast} from '../src/ai-slide-designs.js';
import {handleAiSlides, readSlidePrompt} from '../src/ai-slides.js';

const style = family => ({name: `디자인 ${family}`, description: '명확한 제목과 편안한 간격', family,
  backgroundColor: 0xFFF8FAFC, textColor: 0xFF102030, accentColor: 0xFF0044AA, titleColor: family === 'banner' ? 0xFFFFFFFF : 0xFF002244,
  fontFamily: 'sans', titleWeight: 900, bodyWeight: 700, italic: false, spacing: 1, motif: ''});
const result = {designs: ['banner', 'focus', 'editorial'].map(style), warnings: []};
const source = readSlideDesignPrompt({prompt: '우리 센터의 밝고 차분한 보드'});
const reason = name => error => error.details?.reason === name;
function png(width = 1024, height = 768) {
  const bytes = Buffer.alloc(24);
  Buffer.from([137,80,78,71,13,10,26,10]).copy(bytes);
  bytes.write('IHDR', 12); bytes.writeUInt32BE(width, 16); bytes.writeUInt32BE(height, 20);
  return bytes.toString('base64');
}
const reference = () => readSlideDesignPrompt({prompt: source.prompt, imageBase64: png(), mimeType: 'image/png'});
const providerColors = value => ({...value, designs: value.designs?.map(design => ({...design,
  ...Object.fromEntries(['backgroundColor', 'textColor', 'accentColor', 'titleColor'].map(key =>
    [key, typeof design[key] === 'number' ? `#${(design[key] & 0xFFFFFF).toString(16).padStart(6, '0')}` : design[key]]))}))});
const completed = value => ({ok: true, json: async () => ({status: 'completed',
  output: [{type: 'message', content: [{type: 'output_text', text: JSON.stringify(providerColors(value))}]}],
  usage: {input_tokens: 2000, output_tokens: 500}})});

test('design cache keys include normalized brief, image bytes, model and a namespace separate from content', () => {
  assert.equal(readSlideDesignPrompt({prompt: ' Calm\r\nblue '}).key, readSlideDesignPrompt({prompt: 'Calm\nblue'}).key);
  assert.notEqual(source.key, reference().key);
  assert.notEqual(source.key, readSlidePrompt({prompt: source.prompt}).key);
  assert.notEqual(reference().key, readSlideDesignPrompt({prompt: source.prompt, imageBase64: png(800)}).key);
  assert.notEqual(reference().key, readSlideDesignPrompt({prompt: 'different brief', imageBase64: png()}).key);
  assert.equal(reference().key, readSlideDesignPrompt({prompt: source.prompt, imageBase64: png()}).key);
  const oldKey = createHash('sha256').update(JSON.stringify({version: 'slide-design-v1', model: 'gpt-6-luna', prompt: source.prompt, image: null})).digest('hex');
  assert.notEqual(source.key, oldKey, 'old decimal-color jobs must not bypass palette validation');
});

test('input rejects invalid briefs, image dimensions, mismatched MIME and image URLs before charging', () => {
  for (const prompt of [null, '', '  ', 'x'.repeat(6001)]) {
    assert.throws(() => readSlideDesignPrompt({prompt}), reason('invalid-prompt'));
  }
  for (const change of [{imageBase64: null}, {imageBase64: 'https://example.com/image.png'},
    {imageBase64: png(2049)}, {imageBase64: png(0)}, {imageBase64: 'A'.repeat(6 * 1024 * 1024)},
    {mimeType: 'image/png'}, {imageBase64: png(), mimeType: 'image/jpeg'}, {imageBase64: png(), mimeType: 'image/svg+xml'}]) {
    assert.throws(() => readSlideDesignPrompt({prompt: 'calm', ...change}), reason('invalid-image'));
  }
});

test('text proposals require exactly three structurally distinct supported families', () => {
  assert.deepEqual(validateSlideDesigns(result, source), result);
  for (const designs of [[], result.designs.slice(0, 1), [...result.designs, style('cards')]]) {
    assert.throws(() => validateSlideDesigns({...result, designs}, source), reason('invalid-design-result'));
  }
  assert.throws(() => validateSlideDesigns({...result, designs: Array(3).fill(style('banner'))}, source), reason('duplicate-design-family'));
  assert.equal(slideDesignSchema().properties.designs.minItems, 3);
  assert.equal(slideDesignSchema(true).properties.designs.maxItems, 1);
});

test('reference proposals require one style and always explain approximation without accumulating warnings', () => {
  const raw = {designs: [style('editorial')], warnings: ['서예 장식은 별도 자산이 필요해요.']};
  const value = validateSlideDesigns(raw, reference());
  assert.deepEqual(value.warnings, [REFERENCE_DESIGN_WARNING, ...raw.warnings]);
  assert.deepEqual(validateSlideDesigns(value, reference()), value);
  assert.throws(() => validateSlideDesigns(result, reference()), reason('invalid-design-result'));
  assert.equal(validateSlideDesigns({...raw, warnings: Array(5).fill('확인해 주세요.')}, reference()).warnings.length, 5);
});

test('style validator enforces opacity, supported typography, finite spacing and a visual-only shape', () => {
  for (const change of [{name: ''}, {name: 'a'.repeat(61)}, {description: 'a'.repeat(161)}, {description: 'one\ntwo'},
    {family: 'freeform'}, {fontFamily: 'Comic Sans'}, {titleWeight: 750}, {bodyWeight: 300}, {italic: 'false'},
    {spacing: Infinity}, {spacing: '1'}, {spacing: .79}, {spacing: 1.51}, {motif: 'a'.repeat(13)}, {motif: '\u0000'},
    {backgroundColor: 0x00FFFFFF}, {textColor: -1}, {accentColor: 0x100000000}, {titleColor: 1.5},
    {workSeconds: 60}, {imageUrl: 'https://example.com'}, {prompt: 'workout content'}]) {
    assert.throws(() => validateSlideDesigns({...result, designs: [{...result.designs[0], ...change}, ...result.designs.slice(1)]}, source), reason('invalid-design-result'));
  }
  assert.throws(() => validateSlideDesigns({...result, unexpected: 'private'}, source), reason('invalid-design-result'));
  assert.throws(() => validateSlideDesigns({...result, warnings: ['a'.repeat(251)]}, source), reason('invalid-design-result'));
  const missing = {...result.designs[0]}; delete missing.motif;
  assert.throws(() => validateSlideDesigns({...result, designs: [missing, ...result.designs.slice(1)]}, source), reason('invalid-design-result'));
});

test('provider hex colors normalize exactly to opaque client integers without model arithmetic', () => {
  assert.deepEqual(normalizeProviderSlideDesigns(providerColors(result), source), result);
  const referenceStyle = {designs: [{...style('editorial'), backgroundColor: '#000000', textColor: '#FFFFFF',
    accentColor: '#aC1352', titleColor: '#CC3333'}], warnings: []};
  const normalized = normalizeProviderSlideDesigns(referenceStyle, reference());
  assert.equal(normalized.designs[0].titleColor, 0xFFCC3333);
  assert.equal(normalized.designs[0].accentColor, 0xFFAC1352);
  assert.equal(normalized.designs[0].backgroundColor, 0xFF000000);
  for (const color of ['#FFF', '#FF000000', 'CC3333', '#GG0000', '#CC3333 ', 4290441043, null]) {
    assert.throws(() => normalizeProviderSlideDesigns({...referenceStyle,
      designs: [{...referenceStyle.designs[0], titleColor: color}]}, reference()), reason('invalid-design-color'));
  }
});

test('palette validation rejects invisible body and title colors using the actual family background', () => {
  assert.equal(designColorContrast(0xFF000000, 0xFFFFFFFF), 21);
  assert.equal(designColorContrast(0xFFFFFFFF, 0xFFFFFFFF), 1);
  for (const change of [{family: 'focus', textColor: 0xFFFFFFFF, backgroundColor: 0xFFFFFFFF},
    {family: 'focus', textColor: 0xFF888888, backgroundColor: 0xFFFFFFFF},
    {family: 'editorial', titleColor: 0xFFFFFFFF, backgroundColor: 0xFFFFFFFF},
    {family: 'banner', titleColor: 0xFF0044AA, accentColor: 0xFF0044AA}]) {
    assert.throws(() => validateSlideDesigns({designs: [{...style('editorial'), ...change}], warnings: []}, reference()), reason('unreadable-design-palette'));
  }
  // A decorative accent may be pale; only the foreground's actual surface matters.
  assert.doesNotThrow(() => validateSlideDesigns({designs: [{...style('editorial'), accentColor: 0xFFFFFFFF}], warnings: []}, reference()));
});

test('provider receives the brief and optional actual reference with strict bounded schema and no storage', async () => {
  for (const input of [source, reference()]) {
    const raw = input.image ? {designs: [style('editorial')], warnings: []} : result;
    const answer = await requestAiSlideDesigns(input, 'test-only', async (url, options) => {
      assert.equal(url, 'https://api.openai.com/v1/responses');
      const body = JSON.parse(options.body);
      assert.equal(body.model, 'gpt-6-luna'); assert.equal(body.store, false);
      assert.equal(body.reasoning.effort, 'none'); assert.equal(body.max_output_tokens, 2500);
      assert.equal(body.text.format.strict, true);
      assert.equal(body.text.format.schema.properties.designs.maxItems, input.image ? 1 : 3);
      assert.equal(body.text.format.schema.properties.designs.items.properties.titleColor.type, 'string');
      assert.deepEqual(JSON.parse(body.input[0].content[0].text), {styleBrief: input.prompt});
      assert.match(body.instructions, /untrusted/);
      assert.match(body.instructions, /never workout content/);
      assert.match(body.instructions, /Never claim exact/);
      assert.match(body.instructions, /overall sans or serif family for title, body and timing text/);
      assert.match(body.instructions, /Never calculate decimal ARGB/);
      assert.match(body.instructions, /Banner title text is drawn ON the accentColor/);
      if (input.image) {
        assert.equal(body.input[0].content.length, 2);
        assert.equal(body.input[0].content[1].image_url, `data:image/png;base64,${png()}`);
        assert.match(body.instructions, /STYLE REFERENCE/);
      } else assert.equal(body.input[0].content.length, 1);
      return completed(raw);
    });
    assert.deepEqual(answer.result, validateSlideDesigns(raw, input));
    assert.equal(answer.costMicros, 500);
  }
});

test('provider failures, refusals and incomplete results never expose upstream data', async () => {
  await assert.rejects(requestAiSlideDesigns(source, ''), reason('not-configured'));
  await assert.rejects(requestAiSlideDesigns(source, 'test', async () => {throw Error('secret provider body');}), reason('provider-timeout'));
  for (const response of [{ok: false, status: 429, json: async () => {throw Error('must not read');}},
    {ok: true, json: async () => {throw Error('private');}},
    {ok: true, json: async () => null},
    {ok: true, json: async () => ({status: 'incomplete'})},
    {ok: true, json: async () => ({status: 'completed', output: [{type: 'message', content: [{type: 'refusal', refusal: 'private'}]}]})},
    completed({designs: Array(3).fill(style('banner')), warnings: []})]) {
    await assert.rejects(requestAiSlideDesigns(source, 'test', async () => response), error => !error.message.includes('private'));
  }
});

// Exercise the real shared metering code without contacting Firebase or OpenAI.
function memoryDb(initial = {}) {
  const documents = new Map(Object.entries(initial));
  const snapshot = ref => ({exists: documents.has(ref.path), data: () => documents.get(ref.path)});
  const db = {documents, doc: path => ({path}), runTransaction: async run => run({
    get: async ref => snapshot(ref), getAll: async (...refs) => refs.map(snapshot),
    set: (ref, value, options) => documents.set(ref.path, options?.merge ? {...documents.get(ref.path), ...value} : value),
  })};
  return db;
}
const now = Date.parse('2026-10-09T00:00:00Z');
const premium = {plan: 'premium', status: 'active', validUntilMs: now + 86400000};

test('design access alias and content generation share premium, quota, budget, cooldown and separate cache jobs', async () => {
  const db = memoryDb({'subscriptionEntitlements/owner': premium});
  let calls = 0;
  const options = {db, uid: 'owner', apiKey: 'test', now,
    input: {action: 'generate', prompt: 'Run 1km'}, recognize: async () => {calls++; return {result, costMicros: 500};}};
  const access = await handleAiSlideDesigns({...options, input: {action: 'access'}});
  assert.equal(access.limit, 30); assert.equal(calls, 0);
  assert.equal((await handleAiSlideDesigns(options)).remaining, 29);
  assert.equal((await handleAiSlideDesigns(options)).cached, true); assert.equal(calls, 1);
  const content = {complete: true, slides: [{title: 'RUN', layout: 'list', sourceTitleLineIds: [],
    sections: [{heading: '', lines: ['Run 1km'], sourceLineIds: [1]}], workSeconds: null, restSeconds: null, sets: null}], warnings: []};
  await assert.rejects(handleAiSlides({...options, recognize: async () => ({result: content, costMicros: 500})}), reason('cooldown'));
  assert.equal((await handleAiSlides({...options, now: now + 6000, recognize: async () => ({result: content, costMicros: 500})})).remaining, 28);
  assert.equal(db.documents.get('aiTimerBudgets/2026-10').spentMicros, 1000);
  assert.equal([...db.documents.keys()].filter(key => key.includes('/aiSlidesJobs/')).length, 2);
  db.documents.get('users/owner/aiSlidesUsage/2026-10').used = 30;
  assert.equal((await handleAiSlideDesigns(options)).cached, true);
  await assert.rejects(handleAiSlideDesigns({...options, now: now + 12000, input: {...options.input, prompt: 'fresh'}}), reason('user-limit'));
  db.documents.set('subscriptionEntitlements/owner', {...premium, plan: 'free'});
  await assert.rejects(handleAiSlideDesigns(options), reason('premium-required'));
});

test('invalid designs refund quota; invalid input never reserves it; cached results are revalidated', async () => {
  const db = memoryDb({'subscriptionEntitlements/owner': premium});
  const options = {db, uid: 'owner', apiKey: 'test', now, input: {action: 'generate', prompt: source.prompt}};
  await assert.rejects(handleAiSlideDesigns({...options, input: {...options.input, imageBase64: 'bad'}}), reason('invalid-image'));
  assert.equal(db.documents.size, 1);
  await assert.rejects(handleAiSlideDesigns({...options, recognize: async () => ({result: {designs: [], warnings: []}, costMicros: 1})}), reason('invalid-design-result'));
  assert.equal(db.documents.get('users/owner/aiSlidesUsage/2026-10').used, 0);
  assert.equal(db.documents.get('aiTimerBudgets/2026-10').spentMicros, 10000);
  db.documents.set(`users/owner/aiSlidesJobs/${source.key}`, {status: 'completed', result: {slides: []}, expiresAtMs: now + 1000});
  await assert.rejects(handleAiSlideDesigns(options), reason('invalid-design-result'));
  await assert.rejects(handleAiSlideDesigns({...options, uid: null}), {code: 'unauthenticated'});
  await assert.rejects(handleAiSlideDesigns({...options, input: {action: 'save'}}), reason('invalid-action'));
});

test('unreadable palettes refund shared successful-use quota instead of reaching the client', async () => {
  const db = memoryDb({'subscriptionEntitlements/owner': premium});
  const invisible = {...result, designs: result.designs.map(d => ({...d, textColor: d.backgroundColor}))};
  await assert.rejects(handleAiSlideDesigns({db, uid: 'owner', apiKey: 'test', now,
    input: {action: 'generate', prompt: source.prompt}, recognize: async () => ({result: invisible, costMicros: 1})}), reason('unreadable-design-palette'));
  assert.equal(db.documents.get('users/owner/aiSlidesUsage/2026-10').used, 0);
  assert.equal(db.documents.get(`users/owner/aiSlidesJobs/${source.key}`).status, 'failed');
});
