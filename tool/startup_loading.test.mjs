import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const read = file => fs.readFileSync(new URL(`../${file}`, import.meta.url), 'utf8');

function fixture() {
  const nodes = new Map(['app-startup', 'startup-error', 'startup-retry'].map(id => [id, {
    attrs: new Map(), hidden: true, removed: false, focused: false, events: new Map(),
    setAttribute(k, v) { this.attrs.set(k, v); },
    removeAttribute(k) { this.attrs.delete(k); },
    toggleAttribute(k, value) { value ? this.attrs.set(k, '') : this.attrs.delete(k); },
    addEventListener(k, f) { this.events.set(k, f); },
    removeEventListener(k) { this.events.delete(k); },
    remove() { this.removed = true; }, focus() { this.focused = true; },
  }]));
  const docEvents = new Map(), winEvents = new Map();
  const document = {hidden: false, getElementById: id => nodes.get(id),
    addEventListener: (k, f) => docEvents.set(k, f), removeEventListener: k => docEvents.delete(k)};
  let reloads = 0;
  const window = {location: {reload: () => reloads++},
    addEventListener: (k, f) => winEvents.set(k, f), removeEventListener: k => winEvents.delete(k)};
  vm.runInNewContext(read('web/startup_loading.js'), {window, document});
  return {window, document, nodes, winEvents, docEvents, reloads: () => reloads};
}

test('local HTML and Flutter share the original mark, canvas, geometry and motion bounds', () => {
  const html = read('web/index.html'), css = read('web/startup_loading.css');
  const dart = read('lib/src/app/core/widgets/soft_rhythm_loading_mark.dart');
  const mark = read('lib/src/app/core/widgets/soft_rhythm_mark.dart');
  const colors = read('lib/src/app/core/theme/app_colors.dart');
  const asset = mark.match(/static const asset = '([^']+)'/)[1];
  assert.match(html, new RegExp(`src="assets/${asset}"`));
  assert.equal((html.match(/role="status"/g) ?? []).length, 1);
  assert.match(html, /aria-label="앱 준비 중"/);
  assert.match(html, /width="128" height="128"/);
  assert.match(dart, /size = 128/);
  assert.match(css, /background: #F7F5EF/);
  assert.match(colors, /canvas = Color\(0xFFF7F5EF\)/);
  assert.match(css, /ease-in-out/); assert.match(dart, /Curves.easeInOut\)/);
  assert.match(css, /1800ms/); assert.match(dart, /milliseconds: 1800/);
  for (const value of ['.97', '.80']) { assert.ok(css.includes(value)); assert.ok(dart.includes(value)); }
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.doesNotMatch(html, /https?:\/\/[^\s"<]+\.(png|svg|jpg)/);
  assert.equal(fs.existsSync(new URL(`../${asset}`, import.meta.url)), true);
});

test('hidden/page cache pauses, first frame removes loader and all listeners without a timer', () => {
  const f = fixture(), root = f.nodes.get('app-startup');
  f.document.hidden = true; f.docEvents.get('visibilitychange')();
  assert.equal(root.attrs.has('data-paused'), true);
  f.document.hidden = false; f.winEvents.get('pageshow')();
  assert.equal(root.attrs.has('data-paused'), false);
  f.winEvents.get('pagehide')(); assert.equal(root.attrs.has('data-paused'), true);
  f.winEvents.get('flutter-first-frame')();
  assert.equal(root.removed, true);
  assert.equal(f.docEvents.size, 0);
  assert.equal(f.winEvents.has('error'), false);
  assert.equal(f.nodes.get('startup-retry').events.size, 0);
  f.window.appStartup.fail();
  assert.equal(f.nodes.get('startup-error').hidden, true, 'late failures cannot overlay Flutter');
});

test('script failure keeps static original logo and accessible reload action', () => {
  const f = fixture();
  f.winEvents.get('error')({target: {tagName: 'SCRIPT'}});
  assert.equal(f.nodes.get('app-startup').attrs.get('role'), 'alert');
  assert.equal(f.nodes.get('app-startup').attrs.has('data-failed'), true);
  assert.equal(f.nodes.get('startup-error').hidden, false);
  assert.equal(f.nodes.get('startup-retry').focused, true);
  f.nodes.get('startup-retry').events.get('click')();
  assert.equal(f.reloads(), 1);
});

for (const stage of ['load', 'engine', 'runApp', 'success']) {
  test(`bootstrap ${stage} preserves first-frame handoff / failure recovery`, async () => {
    let failed = 0, initialized = 0, ran = 0;
    const source = read('web/flutter_bootstrap.js').replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
    await vm.runInNewContext(source, {window: {appStartup: {fail: () => failed++}}, _flutter: {loader: {
      async load(options) {
        if (stage === 'load') throw Error('offline');
        await options.onEntrypointLoaded({async initializeEngine() {
          initialized++;
          if (stage === 'engine') throw Error('engine unavailable');
          return {async runApp() { ran++; if (stage === 'runApp') throw Error('run failed'); }};
        }});
      },
    }}});
    assert.equal(failed, stage === 'success' ? 0 : 1);
    assert.equal(initialized, stage === 'load' ? 0 : 1);
    assert.equal(ran, ['runApp', 'success'].includes(stage) ? 1 : 0);
  });
}
