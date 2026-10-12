import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import {renderPlatformOutputs} from './brand-platforms.mjs';

const config = JSON.parse(fs.readFileSync(new URL('../config/brand.json', import.meta.url)));
const read = file => fs.readFileSync(new URL(`../${file}`, import.meta.url), 'utf8');
const output = input => renderPlatformOutputs(input, read);
const swiftString = literal => JSON.parse(literal.replace(/\\u\{([0-9a-f]+)\}/gi,
  (_, hex) => JSON.stringify(String.fromCodePoint(parseInt(hex, 16))).slice(1, -1)));

test('platform labels preserve existing variants and all unrelated metadata', () => {
  const generated = output(config);
  const intentLiteral = generated.get('ios/Brand/ClassControlIntentBrand.swift')
    .match(/IntentDescription\(("(?:\\.|[^"\\])*")\)/)[1];
  assert.equal(swiftString(intentLiteral),
    `${config.display.nameKo}의 현재 연결 수업을 조작합니다. 음악 재생에는 영향을 주지 않습니다.`);
  for (const file of ['ios/Runner/Info.plist', 'ios/ClassActivity/Info.plist',
    'macos/Runner/Info.plist', 'web/index.html', 'web/manifest.json']) {
    assert.equal(generated.get(file), read(file), `${file} current display must remain unchanged`);
  }
  const variants = structuredClone(config);
  for (const key of Object.keys(variants.platforms)) variants.platforms[key] = `Other ${key}`;
  const changed = output(variants);
  assert.equal(changed.get('ios/Runner/Info.plist').match(/<key>CFBundleIdentifier<\/key>\s*<string>(.*?)<\/string>/s)[1], '$(PRODUCT_BUNDLE_IDENTIFIER)');
  assert.equal(changed.get('ios/Runner/Info.plist').match(/<key>CFBundleExecutable<\/key>\s*<string>(.*?)<\/string>/s)[1], '$(EXECUTABLE_NAME)');
  assert.equal(changed.get('macos/Runner/Info.plist').match(/<key>CFBundleName<\/key>\s*<string>(.*?)<\/string>/s)[1], '$(PRODUCT_NAME)');
  const beforeManifest = JSON.parse(read('web/manifest.json'));
  const afterManifest = JSON.parse(changed.get('web/manifest.json'));
  delete beforeManifest.name; delete beforeManifest.short_name;
  delete afterManifest.name; delete afterManifest.short_name;
  assert.deepEqual(afterManifest, beforeManifest);
  assert.match(changed.get('web/index.html'), /<base href="\$FLUTTER_BASE_HREF">/);
  assert.match(read('windows/runner/Runner.rc'), /VALUE "OriginalFilename", "cloud_board.exe"/);
  assert.match(read('windows/runner/Runner.rc'), /VALUE "InternalName", "cloud_board"/);
  assert.match(read('macos/Runner/Configs/AppInfo.xcconfig'), /PRODUCT_NAME = cloud_board/);
  assert.match(read('linux/CMakeLists.txt'), /set\(BINARY_NAME "cloud_board"\)/);
});

test('long display names with quotes, apostrophes, ampersands and backslashes stay data', async () => {
  const variants = structuredClone(config);
  const name = '긴 이름 '.repeat(25) + `O'Brien "Studio" & <Board> \\ \\(unsafe) $value 50% 🏋️`;
  variants.display.name = name;
  variants.display.nameKo = name;
  for (const key of Object.keys(variants.platforms)) variants.platforms[key] = name;
  const generated = output(variants);
  const server = await import(`data:text/javascript;base64,${Buffer.from(generated.get('functions/src/config/app-brand.js')).toString('base64')}`);
  assert.deepEqual(server.AppBrand, {name, nameKo: name});
  assert.equal(JSON.parse(generated.get('web/manifest.json')).name, name);
  assert.equal(JSON.parse(generated.get('web/manifest.json')).short_name, name);
  assert.match(generated.get('web/index.html'), /O&apos;Brien &quot;Studio&quot; &amp; &lt;Board&gt;/);
  assert.match(generated.get('ios/Runner/Info.plist'), /O&apos;Brien &quot;Studio&quot; &amp; &lt;Board&gt;/);
  assert.match(generated.get('android/app/src/main/res/values/app_brand.xml'), /O\\&apos;Brien \\&quot;Studio\\&quot; &amp; &lt;Board&gt;/);
  assert.match(generated.get('ios/Brand/AppBrand.swift'), /\\\\\(unsafe\)/);
  assert.match(generated.get('ios/Brand/ClassControlIntentBrand.swift'), /\\\\\(unsafe\)/);
  assert.match(generated.get('windows/runner/app_brand.h'), /L"\\uae34/);
  const resource = generated.get('windows/runner/app_brand.h').match(/APP_BRAND_RESOURCE_NAME L"([^\n]+)"/)[1];
  assert.equal(resource.replace(/\\x([0-9a-f]{4})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16))), name);
  assert.match(generated.get('android/app/src/main/res/values/app_brand.xml'), /formatted="false"/);
});

test('missing or duplicated owned display fields fail without rewriting other settings', () => {
  for (const [file, pattern] of [
    ['web/index.html', /<title>[^<]*<\/title>/],
    ['web/manifest.json', /"short_name"\s*:\s*"(?:\\.|[^"\\])*"/],
  ]) {
    const original = read(file).match(pattern)[0];
    for (const replacement of ['', `${original}\n${original}`]) {
      assert.throws(() => renderPlatformOutputs(config, path =>
        path === file ? read(path).replace(original, replacement) : read(path)), /Expected one/);
    }
  }
  assert.throws(() => renderPlatformOutputs(config, path => path === 'ios/Runner/Info.plist'
    ? read(path).replace('CFBundleDisplayName', 'UnrelatedKey') : read(path)), /Expected one/);
  assert.throws(() => renderPlatformOutputs(config, path => path === 'ios/Runner/Info.plist'
    ? read(path).replace('<key>CFBundleDisplayName</key>', '<key>CFBundleDisplayName</key><true/><key>CFBundleDisplayName</key>') : read(path)), /found 2/);
  assert.throws(() => renderPlatformOutputs(config, path => path === 'web/manifest.json'
    ? read(path).replace('"short_name":', '"short_name": null, "short_name":') : read(path)), /found 2/);
});

test('generated Swift is included by both app and extension while identifiers stay stable', () => {
  const project = read('ios/Runner.xcodeproj/project.pbxproj');
  assert.equal((project.match(/CB202610120000000000013[23] \/\* AppBrand.swift in Sources \*\//g) ?? []).length, 4);
  assert.match(project, /path = Brand\/AppBrand.swift; sourceTree = SOURCE_ROOT;/);
  assert.equal((project.match(/CB2026101200000000000135 \/\* ClassControlIntentBrand.swift in Sources \*\//g) ?? []).length, 2);
  assert.match(read('ios/Brand/ClassControlIntentBrand.swift'), /extension ControlClassIntent/);
  assert.match(project, /PRODUCT_BUNDLE_IDENTIFIER = com.sunmkim.cloudboard.ClassActivity;/);
  assert.match(read('android/app/src/main/AndroidManifest.xml'), /android:label="@string\/app_name"/);
});
