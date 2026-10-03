import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {appleApiReady, appleSecretBindings, appleSecretNames} from '../src/apple-billing-config.js';

test('Apple secret binding is opt-in and runtime requires every credential', () => {
  const credentials = Object.fromEntries(appleSecretNames.map(name => [name, 'test-value']));
  for (const flag of [undefined, '', 'false', 'TRUE', '1']) {
    const env = {...credentials, APPLE_IAP_SECRETS_ENABLED: flag};
    assert.deepEqual(appleSecretBindings(env), []);
    assert.equal(appleApiReady(env), false);
  }
  const enabled = {...credentials, APPLE_IAP_SECRETS_ENABLED: 'true'};
  assert.deepEqual(appleSecretBindings(enabled), appleSecretNames);
  assert.equal(appleApiReady(enabled), true);
  for (const name of appleSecretNames) {
    assert.equal(appleApiReady({...enabled, [name]: undefined}), false);
    assert.equal(appleApiReady({...enabled, [name]: ' '}), false);
  }
});

test('Firebase function metadata supports optional Apple and AI secrets but keeps SMS secrets', () => {
  for (const flag of ['false', 'true']) {
    const output = execFileSync(process.execPath, ['--input-type=module', '-e', `
      const functions = await import('./src/index.js');
      console.log(JSON.stringify(Object.fromEntries(Object.entries(functions).map(([name, fn]) =>
        [name, (fn.__endpoint?.secretEnvironmentVariables ?? []).map(secret => secret.key)]))));
    `], {cwd: new URL('..', import.meta.url), encoding: 'utf8',
      env: {...process.env, GCLOUD_PROJECT: 'demo-cloudboard-billing',
        APPLE_IAP_SECRETS_ENABLED: flag, AI_TIMER_SECRETS_ENABLED: flag}});
    const functions = JSON.parse(output);
    for (const name of ['cloudboardBilling', 'processAppStoreNotification', 'reconcileAppStoreBilling']) {
      assert.deepEqual(functions[name], flag === 'true' ? appleSecretNames : []);
    }
    assert.deepEqual(functions.cloudboardAppOnboarding,
      ['CLOUDBOARD_ONBOARDING_SECRET', 'SOLAPI_API_KEY', 'SOLAPI_API_SECRET']);
    assert.deepEqual(functions.cloudboardAiTimer, flag === 'true' ? ['OPENAI_API_KEY'] : []);
  }
});
