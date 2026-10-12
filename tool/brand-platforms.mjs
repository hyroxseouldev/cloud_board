// Native/server display outputs for tool/brand.mjs. Only the named display
// fields are patched in existing files; all technical settings stay verbatim.
const notice = 'Generated from config/brand.json by tool/brand.mjs. Do not edit.';
const xml = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
const swift = value => `"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')
  .replace(/[\x00-\x1f\x7f\u2028\u2029]/gu, c => `\\u{${c.codePointAt(0).toString(16)}}`)}"`;
const cppWide = value => `L${JSON.stringify(value).replace(/[^\x00-\x7f]/gu,
  c => c.codePointAt(0) <= 0xffff ? `\\u${c.codePointAt(0).toString(16).padStart(4, '0')}`
    : `\\U${c.codePointAt(0).toString(16).padStart(8, '0')}`)}`;
// RC strings do not use C++ quote escaping. Four-digit UTF-16 escapes also
// avoid the resource compiler's active code page and retain surrogate pairs.
// https://learn.microsoft.com/windows/win32/menurc/stringtable-resource
const rcWide = value => `L"${value.split('').map(c => `\\x${c.charCodeAt(0).toString(16).padStart(4, '0')}`).join('')}"`;

function replaceOne(text, pattern, replacement, label) {
  const matches = [...text.matchAll(pattern)];
  if (matches.length !== 1) throw new Error(`Expected one ${label}; found ${matches.length}`);
  return text.replace(pattern, replacement);
}
function plist(text, key, value, path) {
  replaceOne(text, new RegExp(`<key>${key}</key>`, 'g'), match => match, `${path}:${key}`);
  return replaceOne(text, new RegExp(`(<key>${key}</key>\\s*<string>)[^<]*(</string>)`, 'g'),
    (_, before, after) => `${before}${xml(value)}${after}`, `${path}:${key}`);
}

export function renderPlatformOutputs(config, readFile) {
  const {display, platforms} = config;
  const output = new Map();
  output.set('functions/src/config/app-brand.js', `// ${notice}\nexport const AppBrand = Object.freeze(${JSON.stringify({name: display.name, nameKo: display.nameKo}, null, 2)});\n`);
  output.set('ios/Brand/AppBrand.swift', `// ${notice}\nimport Foundation\n\nenum AppBrand {\n    static let name = ${swift(display.name)}\n    static let nameKo = ${swift(display.nameKo)}\n}\n`);
  // AppIntents' metadata extractor requires a literal LocalizedStringResource;
  // interpolation type-checks but fails when Xcode extracts the intent metadata.
  const controlsDescription = `${display.nameKo}의 현재 연결 수업을 조작합니다. 음악 재생에는 영향을 주지 않습니다.`;
  output.set('ios/Brand/ClassControlIntentBrand.swift', `// ${notice}\nimport AppIntents\n\n@available(iOS 16.0, *)\nextension ControlClassIntent {\n    static var description = IntentDescription(${swift(controlsDescription)})\n}\n`);
  // Android has its own string escaping in addition to XML escaping. Quotes
  // preserve leading/trailing whitespace and keep @/? prefixes literal.
  const android = platforms.androidDisplayName.replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"').replaceAll("'", "\\'");
  output.set('android/app/src/main/res/values/app_brand.xml', `<?xml version="1.0" encoding="utf-8"?>\n<!-- ${notice} -->\n<resources>\n    <string name="app_name" translatable="false" formatted="false">"${xml(android)}"</string>\n</resources>\n`);
  output.set('windows/runner/app_brand.h', `// ${notice}\n#pragma once\n\n#define APP_BRAND_RESOURCE_NAME ${rcWide(platforms.windowsDisplayName)}\n#define APP_BRAND_WINDOW_TITLE ${cppWide(platforms.windowsDisplayName)}\n`);
  output.set('linux/runner/app_brand.h', `// ${notice}\n#pragma once\n\n#define APP_BRAND_DISPLAY_NAME ${JSON.stringify(platforms.linuxDisplayName)}\n`);

  const runnerPlist = 'ios/Runner/Info.plist';
  output.set(runnerPlist, plist(plist(readFile(runnerPlist), 'CFBundleDisplayName',
    platforms.iosDisplayName, runnerPlist), 'CFBundleName', platforms.iosBundleName, runnerPlist));
  const activityPlist = 'ios/ClassActivity/Info.plist';
  output.set(activityPlist, plist(readFile(activityPlist), 'CFBundleDisplayName',
    platforms.iosActivityDisplayName, activityPlist));
  const macPlist = 'macos/Runner/Info.plist';
  // FlutterAppDelegate uses CFBundleDisplayName for window/menu titles. Do not
  // change PRODUCT_NAME: that is also the executable and bundle artifact name.
  output.set(macPlist, plist(readFile(macPlist), 'CFBundleDisplayName', platforms.macosDisplayName, macPlist));

  const html = 'web/index.html';
  let htmlText = replaceOne(readFile(html), /(<title>)[^<]*(<\/title>)/g,
    (_, before, after) => `${before}${xml(platforms.webTitle)}${after}`, `${html}:title`);
  htmlText = replaceOne(htmlText, /(<meta name="apple-mobile-web-app-title" content=")[^"]*(">)/g,
    (_, before, after) => `${before}${xml(platforms.webName)}${after}`, `${html}:apple-mobile-web-app-title`);
  output.set(html, htmlText);
  const manifest = 'web/manifest.json';
  let manifestText = readFile(manifest);
  for (const [key, value] of [['name', platforms.webName], ['short_name', platforms.webShortName]]) {
    replaceOne(manifestText, new RegExp(`"${key}"\\s*:`, 'g'), match => match, `${manifest}:${key}`);
    manifestText = replaceOne(manifestText, new RegExp(`("${key}"\\s*:\\s*)"(?:\\\\.|[^"\\\\])*"`, 'g'),
      (_, before) => `${before}${JSON.stringify(value)}`, `${manifest}:${key}`);
  }
  output.set(manifest, manifestText);
  return output;
}
