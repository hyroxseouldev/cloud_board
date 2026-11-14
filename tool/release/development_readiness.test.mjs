import test from 'node:test';
import assert from 'node:assert/strict';
import {inspectDevelopmentIos} from './development_readiness.mjs';

test('development store diagnostics read metadata without creating apps or profiles', async () => {
  const report = await inspectDevelopmentIos('test-token', async (url, options) => {
    assert.equal(options.method, undefined);
    let data;
    if (url.includes('/apps?')) data = [{id: '123'}];
    else if (url.includes('/bundleIds?')) data = [{id: 'BUNDLE1',
      attributes: {identifier: new URL(url).searchParams.get('filter[identifier]')}}];
    else if (url.includes('/profiles?')) data = [
      {attributes: {profileType: 'IOS_APP_STORE', profileState: 'ACTIVE', expirationDate: '2099-01-01'}},
      {attributes: {profileType: 'IOS_APP_DEVELOPMENT', profileState: 'ACTIVE', expirationDate: '2099-01-01'}},
      {attributes: {profileType: 'IOS_APP_STORE', profileState: 'INVALID', expirationDate: '2099-01-01'}},
    ];
    else if (url.endsWith('/bundleIdCapabilities')) data = [{attributes: {capabilityType: 'APPLE_ID_AUTH'}}];
    else assert.fail('Unexpected API');
    return {ok: true, json: async () => ({data})};
  });
  assert.equal(report.storeAppRegistered, true);
  assert.equal(report.bundles.length, 2);
  assert(report.bundles.every(bundle => bundle.activeAppStoreProfileCount === 1));
  assert.equal(report.bundles[0].appleSignInCapability, true);
  assert.equal(report.certificateAndProfilePrivateKeyMatch, 'not_verified');
  assert(!JSON.stringify(report).includes('test-token'));
});

const mainBundle = 'com.sunmkim.cloudboard.dev';
const extensionBundle = `${mainBundle}.ClassActivity`;
for (const [name, identifiers, registered] of [
  ['prefix includes extension before exact app', [extensionBundle, mainBundle], true],
  ['one exact app', [mainBundle], true],
  ['only extension without exact app', [extensionBundle], false],
  ['duplicate exact identifiers', [mainBundle, mainBundle], false],
]) {
  test(`bundle inventory requires a unique exact match: ${name}`, async () => {
    const inspected = [];
    const report = await inspectDevelopmentIos('test-token', async (url, options) => {
      assert.equal(options.method, undefined);
      const parsed = new URL(url);
      let data;
      if (parsed.pathname === '/v1/apps') data = [{id: '123'}];
      else if (parsed.pathname === '/v1/bundleIds') {
        const query = parsed.searchParams.get('filter[identifier]');
        data = query === mainBundle
          ? identifiers.map((identifier, index) => ({id: `MATCH${index}`, attributes: {identifier}}))
          : [{id: 'EXTENSION', attributes: {identifier: extensionBundle}}];
      } else {
        inspected.push(parsed.pathname);
        if (parsed.pathname.endsWith('/bundleIdCapabilities')) {
          assert.equal(parsed.search, '', 'Apple capability relationship rejects limit');
        }
        data = parsed.pathname.endsWith('/profiles')
          ? [{attributes: {profileType: 'IOS_APP_STORE', profileState: 'ACTIVE', expirationDate: '2099-01-01'}}]
          : [{attributes: {capabilityType: 'APPLE_ID_AUTH'}}];
      }
      return {ok: true, json: async () => ({data})};
    });
    assert.equal(report.bundles[0].registered, registered);
    assert.equal(report.bundles[1].registered, true);
    if (registered) {
      const exactId = `MATCH${identifiers.indexOf(mainBundle)}`;
      assert(inspected.includes(`/v1/bundleIds/${exactId}/profiles`));
      assert(inspected.includes(`/v1/bundleIds/${exactId}/bundleIdCapabilities`));
      assert.equal(report.bundles[0].appleSignInCapability, true);
    } else {
      assert(inspected.every(path => path.includes('/EXTENSION/')));
      assert.equal(report.bundles[0].activeAppStoreProfileCount, undefined);
    }
  });
}

test('missing app and authorization failure are distinct and expose no API body', async () => {
  const report = await inspectDevelopmentIos('test-token', async () => ({ok: true, json: async () => ({data: []})}));
  assert.equal(report.storeAppRegistered, false);
  assert(report.bundles.every(bundle => !bundle.registered));
  await assert.rejects(inspectDevelopmentIos('test-token', async () => ({ok: false, status: 403,
    json: async () => ({secret: 'private-response'})})), error => /HTTP 403/.test(error.message) && !error.message.includes('private-response'));
});
