import assert from 'node:assert/strict';
import {createPrivateKey, sign} from 'node:crypto';
import {readFileSync, appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

const base = 'https://api.appstoreconnect.apple.com';
export function highestIosBuild(builds) {
  assert(Array.isArray(builds) && builds.length > 0, 'App Store Connect build history is missing');
  const numbers = builds.map(build => {
    const version = build.attributes?.version;
    assert(/^[1-9]\d*$/.test(version), 'Cannot safely allocate from an unrecognized iOS build number');
    const number = Number(version);
    assert(Number.isSafeInteger(number), 'Invalid iOS build number');
    return number;
  });
  return Math.max(...numbers);
}
export async function inventoryIos(token, request = fetch) {
  async function get(url) {
    assert(url.startsWith(`${base}/v1/`), 'Unexpected App Store Connect pagination target');
    const response = await request(url, {headers: {Authorization: `Bearer ${token}`}, signal: AbortSignal.timeout(30000)});
    assert(response.ok, `App Store Connect metadata request failed: HTTP ${response.status}`);
    return response.json();
  }
  const apps = await get(`${base}/v1/apps?filter%5BbundleId%5D=com.sunmkim.cloudboard&limit=2`);
  assert.equal(apps.data?.length, 1, 'Expected one production iOS app');
  const appId = apps.data[0].id;
  assert(/^\d+$/.test(appId), 'Invalid App Store Connect app identity');
  let next = `${base}/v1/builds?filter%5Bapp%5D=${appId}&sort=-uploadedDate&limit=200`;
  const seen = new Set(), builds = [];
  while (next) {
    assert(!seen.has(next) && seen.size < 1000, 'Invalid or excessive App Store Connect pagination');
    seen.add(next);
    const page = await get(next);
    assert(Array.isArray(page.data), 'Missing App Store Connect build page');
    builds.push(...page.data);
    next = page.links?.next;
  }
  return {appId, highestBuild: highestIosBuild(builds), observedBuildCount: builds.length};
}
function accessToken() {
  const header = {alg: 'ES256', kid: process.env.APP_STORE_CONNECT_KEY_ID, typ: 'JWT'};
  const payload = {iss: process.env.APP_STORE_CONNECT_ISSUER_ID, exp: Math.floor(Date.now() / 1000) + 1200, aud: 'appstoreconnect-v1'};
  assert(header.kid && payload.iss, 'Missing App Store Connect credential');
  const key = createPrivateKey(readFileSync(process.env.APP_STORE_CONNECT_API_KEY_PATH));
  const body = [header, payload].map(value => Buffer.from(JSON.stringify(value)).toString('base64url')).join('.');
  return `${body}.${sign('sha256', Buffer.from(body), {key, dsaEncoding: 'ieee-p1363'}).toString('base64url')}`;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  assert(['--next', '--recheck'].includes(process.argv[2]), 'Unknown iOS release command');
  const inventory = await inventoryIos(accessToken());
  if (process.argv[2] === '--next') {
    const next = inventory.highestBuild + 1;
    assert(Number.isSafeInteger(next));
    assert(process.env.GITHUB_ENV, 'GITHUB_ENV is required');
    appendFileSync(process.env.GITHUB_ENV, `TESTFLIGHT_BUILD_NUMBER=${next}\n`);
    console.log(`TestFlight build ${next}; checked ${inventory.observedBuildCount} existing builds.`);
  } else {
    assert(inventory.highestBuild < Number(process.env.TESTFLIGHT_BUILD_NUMBER), 'App Store Connect advanced; rebuild with a new build number');
    console.log('App Store Connect build history rechecked.');
  }
}
