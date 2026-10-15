import assert from 'node:assert/strict';
import {appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {accessToken} from './ios_build_number.mjs';
import {googleToken, playInventory, packageName} from './play_version_code.mjs';

const bundle = 'com.sunmkim.cloudboard.dev';
export async function inspectDevelopmentIos(token, request = fetch, now = Date.now()) {
  const base = 'https://api.appstoreconnect.apple.com/v1/';
  async function list(path) {
    const result = [];
    let url = base + path;
    for (let page = 0; url && page < 20; page++) {
      assert(url.startsWith(base), 'Unexpected Apple pagination target');
      const response = await request(url, {headers: {Authorization: `Bearer ${token}`}, signal: AbortSignal.timeout(30000)});
      assert(response.ok, `Apple readiness lookup failed (HTTP ${response.status}); registration or access remains unverified`);
      const value = await response.json();
      assert(Array.isArray(value.data), 'Missing Apple metadata');
      result.push(...value.data);
      url = value.links?.next;
    }
    assert(!url, 'Apple readiness pagination incomplete');
    return result;
  }
  const apps = await list(`apps?filter%5BbundleId%5D=${bundle}&fields%5Bapps%5D=bundleId&limit=2`);
  const bundles = [];
  for (const identifier of [bundle, `${bundle}.ClassActivity`]) {
    const ids = await list(`bundleIds?filter%5Bidentifier%5D=${identifier}&limit=2`);
    const entry = {identifier, registered: ids.length === 1};
    if (entry.registered) {
      assert(/^[A-Za-z0-9-]+$/.test(ids[0].id), 'Invalid Apple bundle identity');
      const profiles = await list(`bundleIds/${ids[0].id}/profiles?fields%5Bprofiles%5D=profileType,profileState,expirationDate&limit=200`);
      entry.activeAppStoreProfileCount = profiles.filter(profile => profile.attributes?.profileType === 'IOS_APP_STORE' &&
        profile.attributes.profileState === 'ACTIVE' && Date.parse(profile.attributes.expirationDate) > now).length;
      if (identifier === bundle) {
        const capabilities = await list(`bundleIds/${ids[0].id}/bundleIdCapabilities?limit=200`);
        entry.appleSignInCapability = capabilities.some(capability => capability.attributes?.capabilityType === 'APPLE_ID_AUTH');
      }
    }
    bundles.push(entry);
  }
  return {platform: 'ios', package: bundle, storeAppRegistered: apps.length === 1, bundles,
    certificateAndProfilePrivateKeyMatch: 'not_verified',
    note: 'Read-only inventory. No app, identifier, capability, certificate, profile, build or tester group was changed. Active profiles do not prove the configured signing key is suitable.'};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let report;
  if (process.argv[2] === 'ios') report = await inspectDevelopmentIos(accessToken());
  else if (process.argv[2] === 'android') {
    assert.equal(packageName, bundle, 'Readiness may inspect only the development Android app');
    const token = await googleToken(JSON.parse(process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON || '{}'));
    const inventory = await playInventory(token);
    report = {platform: 'android-tv', package: bundle, storeAppAccessible: true,
      visibleVersionCodes: inventory.currentVersionCodes, uploadKeyMatch: 'not_verified',
      note: 'An empty temporary Play edit was opened, read and deleted without committing. No app, build, release or testers were changed. Full Console upload history and upload key still need verification.'};
  } else throw new Error('Use ios or android');
  const body = JSON.stringify(report, null, 2);
  console.log(body);
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `## Development store inventory (not deployment)\n\n\`\`\`json\n${body}\n\`\`\`\n`);
}
