// Default is read-only validation. Never infer a published build from an upload.
// node functions/tools/release-policy.mjs ios path/to/policy.json [--apply]
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {initializeApp, applicationDefault} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
const [platform, file, flag] = process.argv.slice(2);
assert(['ios', 'android'].includes(platform), 'platform must be ios or android');
assert(file && (!flag || flag === '--apply'), 'supply a JSON file and optional --apply');
const value = JSON.parse(fs.readFileSync(file, 'utf8'));
assert(Object.keys(value).every(k => ['enabled','published','latestBuild','minimumBuild','publishedBuild','version','message','storeUrl'].includes(k)), 'unknown fields');
assert(typeof value.enabled === 'boolean' && typeof value.published === 'boolean');
for (const k of ['latestBuild','minimumBuild','publishedBuild']) assert(Number.isSafeInteger(value[k]) && value[k] > 0 && value[k] < 2147483647, k);
assert(value.minimumBuild <= value.latestBuild && value.latestBuild <= value.publishedBuild, 'invalid build order');
assert(typeof value.version === 'string' && value.version.length > 0 && value.version.length <= 32);
assert(typeof value.message === 'string' && value.message.length <= 500);
const url = new URL(value.storeUrl);
assert(url.protocol === 'https:' && !url.username && !url.password && !url.port && !url.hash, 'unsafe store URL');
assert(platform === 'ios'
  ? url.hostname === 'apps.apple.com' && /^\/(?:[a-z]{2}\/)?app\/(?:[^/]+\/)?id6809105126$/.test(url.pathname) && !url.search
  : url.hostname === 'play.google.com' && url.pathname === '/store/apps/details' &&
    [...url.searchParams].length === 1 && url.searchParams.get('id') === 'com.sunmkim.cloudboard', 'wrong app');
if (value.enabled) assert(value.published, 'never enable an unpublished release');
console.log(JSON.stringify({project:'cloud-board-stationd', document:`appReleases/${platform}`, mode:flag === '--apply' ? 'apply' : 'dry-run', value}, null, 2));
if (flag === '--apply') {
  const app = initializeApp({credential:applicationDefault(), projectId:'cloud-board-stationd'});
  await getFirestore(app).doc(`appReleases/${platform}`).set(value);
  console.log('Release policy saved.');
}
