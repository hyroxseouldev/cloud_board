import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {brandOutputs, checkBrandHardcoding, checkTechnicalContracts, generateBrand, validateBrand} from './brand.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'config/brand.json'), 'utf8'));
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'cloudboard-brand-test-'));
  t.after(() => fs.rmSync(directory, {recursive: true, force: true}));
  for (const file of ['ios/Runner/Info.plist', 'ios/ClassActivity/Info.plist', 'macos/Runner/Info.plist',
    'web/index.html', 'web/manifest.json', 'config/brand.json', 'config/brand-hardcoding-allowlist.json']) {
    fs.mkdirSync(path.dirname(path.join(directory, file)), {recursive: true});
    fs.copyFileSync(path.join(root, file), path.join(directory, file));
  }
  return directory;
}

function guardFixture(t) {
  const directory = fixture(t);
  const generated = [...brandOutputs(directory, config).keys()];
  fs.writeFileSync(path.join(directory, 'config/brand-hardcoding-allowlist.json'), '[]\n');
  return {
    directory,
    check: alternate => checkBrandHardcoding(directory, generated, alternate),
    write(file, text) {
      fs.mkdirSync(path.dirname(path.join(directory, file)), {recursive: true});
      fs.writeFileSync(path.join(directory, file), text);
    },
  };
}

test('current display configuration and generated outputs remain deterministic', () => {
  validateBrand(config);
  const first = brandOutputs(root, config);
  const second = brandOutputs(root, JSON.parse(JSON.stringify(config)));
  assert.deepEqual(first, second);
  for (const [file, contents] of first) assert.equal(read(file), contents, file);
  checkBrandHardcoding(root, [...first.keys()]);
  checkTechnicalContracts(root);
});

test('English/Korean/long names and escaped text reach every output without editing the repository', async t => {
  const directory = fixture(t);
  const alternate = structuredClone(config);
  const name = 'Studio "Cue" & 오늘의 아주 긴 수업 준비 서비스 $edition';
  for (const key of Object.keys(alternate.display)) alternate.display[key] = `${name} ${key}`;
  for (const key of Object.keys(alternate.platforms)) alternate.platforms[key] = `${name} ${key}`;
  alternate.links.supportEmail = 'coach@example.com';
  alternate.links.support = 'mailto:coach@example.com';
  alternate.links.privacy = 'https://example.com/privacy?lang=ko&edition=coach';
  const before = new Map([...brandOutputs(root, config)].map(([file]) => [file, read(file)]));
  generateBrand(directory, alternate);
  const contents = file => fs.readFileSync(path.join(directory, file), 'utf8');
  assert.match(contents('lib/src/app/core/config/app_brand.dart'), /\\\$edition/);
  assert.match(contents('lib/src/app/core/config/app_links.dart'), /coach@example\.com/);
  assert.equal(JSON.parse(contents('web/manifest.json')).name, alternate.platforms.webName);
  assert.match(contents('web/index.html'), /&quot;Cue&quot; &amp;/);
  assert.match(contents('ios/Runner/Info.plist'), /&quot;Cue&quot; &amp;/);
  assert.match(contents('ios/Brand/AppBrand.swift'), /static let nameKo =/);
  assert.match(contents('android/app/src/main/res/values/app_brand.xml'), /&amp;/);
  assert.match(contents('windows/runner/app_brand.h'), /\\u[c-f0-9]{4}/i);
  assert.match(contents('linux/runner/app_brand.h'), /오늘의/);
  const server = await import(pathToFileURL(path.join(directory, 'functions/src/config/app-brand.js')));
  assert.equal(server.AppBrand.name, alternate.display.name);
  assert.equal(server.AppBrand.nameKo, alternate.display.nameKo);
  generateBrand(directory, alternate, {check: true});
  for (const [file, contents] of before) assert.equal(read(file), contents, `test modified real ${file}`);
});

test('check detects drift and regeneration preserves technical plist and PWA fields', t => {
  const directory = fixture(t);
  generateBrand(directory, config);
  const file = path.join(directory, 'web/manifest.json');
  const manifest = JSON.parse(fs.readFileSync(file, 'utf8'));
  manifest.name = 'accidental rename';
  manifest.start_url = './unchanged-technical-route';
  fs.writeFileSync(file, JSON.stringify(manifest, null, 4) + '\n');
  assert.throws(() => generateBrand(directory, config, {check: true}), /outputs are stale/);
  generateBrand(directory, config);
  assert.equal(JSON.parse(fs.readFileSync(file, 'utf8')).start_url, './unchanged-technical-route');
  const plist = path.join(directory, 'ios/Runner/Info.plist');
  const existing = fs.readFileSync(plist, 'utf8');
  assert.match(existing, /\$\(PRODUCT_BUNDLE_IDENTIFIER\)/);
  fs.writeFileSync(plist, existing.replace('<key>CFBundleDisplayName</key>', '<key>MissingDisplayName</key>'));
  assert.throws(() => generateBrand(directory, config), /Expected one.*CFBundleDisplayName/);
});

test('display schema cannot acquire package identifiers, control characters, or unsafe links', () => {
  for (const mutate of [
    value => { value.packageId = 'new.id'; },
    value => { value.display.applicationId = 'new.id'; },
    value => { value.display.name = 'name\nwith newline'; },
    value => { value.links.privacy = 'javascript:alert(1)'; },
    value => { value.links.supportEmail = 'not-an-email'; },
  ]) {
    const value = structuredClone(config);
    mutate(value);
    assert.throws(() => validateBrand(value));
  }
});

test('hardcoding guard catches new product copy and policy/email literals', t => {
  const {directory, check} = guardFixture(t);
  fs.mkdirSync(path.join(directory, 'lib'), {recursive: true});
  const file = path.join(directory, 'lib/brand_regression.dart');
  for (const value of ['CloudBoard 계정', '클라우드보드의 새 기능', config.links.supportEmail, config.links.privacy]) {
    fs.writeFileSync(file, `const label = '${value}';\n`);
    assert.throws(() => check(), /Hardcoded product display text/);
  }
  fs.writeFileSync(file, "const channel = 'com.sunmkim.cloudboard/controls';\n");
  check();
  const alternate = structuredClone(config);
  alternate.display.name = 'FutureStudio';
  fs.writeFileSync(file, "const label = 'FutureStudio 계정';\n");
  assert.throws(() => check(alternate), /Hardcoded product display text/);
});

test('hardcoding guard catches markup text and multiline code literals', t => {
  const {directory, check, write} = guardFixture(t);
  for (const [file, contents, line] of [
    ['android/app/src/main/res/values/strings.xml', '<resources>\n<string name="welcome">CloudBoard 계정</string>\n</resources>', 2],
    ['web/help.html', '<p title="not > a tag">\nCloudBoard 계정\n</p>', 2],
    ['web/help.html', '<p title="CloudBoard 계정">안내</p>', 1],
    ['ios/Other/Info.plist', '<plist><dict>\n<key>title</key><string>CloudBoard 계정</string>\n</dict></plist>', 2],
    ['lib/copy.dart', "const copy = '''\nCloudBoard 계정\n''';", 2],
    ['lib/copy.dart', 'const copy = r"""\nCloudBoard 계정\n""";', 2],
    ['functions/src/copy.js', 'const copy = `\nCloudBoard 계정\n`;', 2],
    ['functions/src/copy.js', 'const copy = "https://example.com/CloudBoard";', 1],
  ]) {
    write(file, contents);
    assert.throws(() => check(), error => error.message.includes(`${file}:${line}:`), file);
    fs.rmSync(path.join(directory, file));
  }
});

test('hardcoding guard ignores comments and technical identifiers', t => {
  const {check, write} = guardFixture(t);
  write('lib/copy.dart', `
// CloudBoard and 'CloudBoard' are documentation.
/* A multiline comment:
   'CloudBoard' and "클라우드보드"
*/
const channel = 'com.sunmkim.cloudboard/controls'; // 'CloudBoard'
const scheme = 'cloudboard://pair';
class CloudBoardTechnicalSymbol {}
`);
  write('functions/src/copy.js', 'const identifier = "cloudboard.saved-colors.v1"; /* "CloudBoard" */');
  write('web/help.html', '<!--\n<p title="CloudBoard">클라우드보드</p>\n-->\n<p>안내</p>');
  write('android/app/src/main/res/values/strings.xml', '<!-- <string name="old">CloudBoard</string> -->\n<resources/>');
  check();
});

test('hardcoding guard preserves exact allowlist text and occurrence counts', t => {
  const {check, write} = guardFixture(t);
  const file = 'lib/legacy.dart';
  write('config/brand-hardcoding-allowlist.json', JSON.stringify([
    {file, text: 'CloudBoard', occurrences: 1, reason: 'Frozen historical default.'},
  ]));
  write(file, '/* "CloudBoard" */\nconst old = "CloudBoard"; // "CloudBoard"');
  check();
  write(file, 'const old = "CloudBoard";\nconst extra = "CloudBoard";');
  assert.throws(() => check(), /Stale\/invalid brand exception.*\(2\/1\)/);
  write(file, 'const old = "CloudBoard 계정";');
  assert.throws(() => check(), /Hardcoded product display text/);
  write(file, '// const old = "CloudBoard";');
  assert.throws(() => check(), /Stale\/invalid brand exception.*\(0\/1\)/);
});

test('hardcoding guard inspects unowned content in partially generated platform files', t => {
  const {directory, check, write} = guardFixture(t);
  generateBrand(directory, config);
  check(); // Owned fields and complete generated outputs remain allowed.
  for (const [file, append] of [
    ['web/index.html', text => text.replace('</body>', '<p>CloudBoard 계정</p></body>')],
    ['web/manifest.json', text => text.replace('{', '{"description":"CloudBoard 계정",')],
    ['ios/Runner/Info.plist', text => text.replace('</dict>', '<key>NewNotice</key><string>CloudBoard 계정</string></dict>')],
  ]) {
    const original = fs.readFileSync(path.join(directory, file), 'utf8');
    write(file, append(original));
    assert.throws(() => check(), error => error.message.includes(`${file}:`), file);
    write(file, original);
  }
});
