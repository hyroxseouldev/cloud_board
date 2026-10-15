import test from 'node:test';
import assert from 'node:assert/strict';
import {inspectDevelopmentIos} from './development_readiness.mjs';

test('development store diagnostics read metadata without creating apps or profiles', async () => {
  const report = await inspectDevelopmentIos('test-token', async (url, options) => {
    assert.equal(options.method, undefined);
    let data;
    if (url.includes('/apps?')) data = [{id: '123'}];
    else if (url.includes('/bundleIds?')) data = [{id: 'BUNDLE1'}];
    else if (url.includes('/profiles?')) data = [
      {attributes: {profileType: 'IOS_APP_STORE', profileState: 'ACTIVE', expirationDate: '2099-01-01'}},
      {attributes: {profileType: 'IOS_APP_DEVELOPMENT', profileState: 'ACTIVE', expirationDate: '2099-01-01'}},
      {attributes: {profileType: 'IOS_APP_STORE', profileState: 'INVALID', expirationDate: '2099-01-01'}},
    ];
    else if (url.includes('/bundleIdCapabilities?')) data = [{attributes: {capabilityType: 'APPLE_ID_AUTH'}}];
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

test('missing app and authorization failure are distinct and expose no API body', async () => {
  const report = await inspectDevelopmentIos('test-token', async () => ({ok: true, json: async () => ({data: []})}));
  assert.equal(report.storeAppRegistered, false);
  assert(report.bundles.every(bundle => !bundle.registered));
  await assert.rejects(inspectDevelopmentIos('test-token', async () => ({ok: false, status: 403,
    json: async () => ({secret: 'private-response'})})), error => /HTTP 403/.test(error.message) && !error.message.includes('private-response'));
});
