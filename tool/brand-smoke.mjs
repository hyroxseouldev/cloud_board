// Build real Dart widgets/defaults with a temporary brand. Never rewrite the
// working tree's configuration or ship the synthetic name in a release.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {generateBrand} from './brand.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'cloudboard-alternate-brand-'));
const originalConfig = fs.readFileSync(path.join(root, 'config/brand.json'), 'utf8');
const flutter = process.env.FLUTTER_BIN || 'flutter';
function run(args) {
  const result = spawnSync(flutter, args, {cwd: temporary, stdio: 'inherit', env: process.env});
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Alternate brand: flutter ${args[0]} failed (${result.status})`);
}

try {
  for (const folder of ['lib', 'test', 'web']) fs.cpSync(path.join(root, folder), path.join(temporary, folder), {recursive: true});
  for (const file of ['pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml', 'ios/Runner/Info.plist',
    'ios/ClassActivity/Info.plist', 'macos/Runner/Info.plist']) {
    fs.mkdirSync(path.dirname(path.join(temporary, file)), {recursive: true});
    fs.copyFileSync(path.join(root, file), path.join(temporary, file));
  }
  fs.symlinkSync(path.join(root, 'assets'), path.join(temporary, 'assets'), 'dir');
  const alternate = JSON.parse(originalConfig);
  alternate.display = {
    name: 'Aurora Class Studio Extended Display Name',
    nameKo: '수업 준비와 진행을 연결하는 아주 긴 한글 브랜드',
    defaultWorkoutBrand: '새 수업 기본 브랜드',
    defaultStoreName: '새 센터 기본 이름',
  };
  for (const key of Object.keys(alternate.platforms)) alternate.platforms[key] = `긴 표시 이름 ${key}`;
  alternate.links = {
    service: 'https://example.com/service', privacy: 'https://example.com/privacy',
    terms: 'https://example.com/terms', support: 'mailto:coach@example.com',
    accountDeletion: 'https://example.com/delete-account', supportEmail: 'coach@example.com',
  };
  generateBrand(temporary, alternate);
  run(['pub', 'get', '--offline']);
  run(['test', '--no-pub',
    'test/app_brand_data_compatibility_test.dart',
    'test/login_welcome_test.dart', 'test/playback_recovery_view_test.dart',
    'test/account_management_section_test.dart', 'test/app_startup_screen_test.dart',
    'test/profile_plan_entitlements_test.dart', 'test/onboarding_test.dart',
    'test/home_workout_loading_test.dart',
  ]);
  console.log('Alternate English/Korean/long brand UI and legacy-data smoke passed.');
} finally {
  fs.rmSync(temporary, {recursive: true, force: true});
  if (fs.readFileSync(path.join(root, 'config/brand.json'), 'utf8') !== originalConfig) {
    throw new Error('Real brand configuration changed during smoke validation');
  }
}
