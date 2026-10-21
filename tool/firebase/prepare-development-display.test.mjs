import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {prepareDevelopmentDisplayPackage, developmentDisplaySource} from './prepare-development-display.mjs';

test('development display package preserves the handler with no provider parameters or exports', async () => {
  const source = readFileSync('functions-legacy/lib/index.js', 'utf8');
  const result = await prepareDevelopmentDisplayPackage('cloud-board-development');
  const entry = readFileSync(`${developmentDisplaySource}/lib/index.js`, 'utf8');
  assert(source.includes(result.handler));
  assert(entry.includes(result.handler));
  assert.equal(readFileSync('functions-legacy/lib/index.js', 'utf8'), source);
  for (const name of ['package.json', 'package-lock.json']) {
    assert.equal(readFileSync(`${developmentDisplaySource}/${name}`, 'utf8'),
      readFileSync(`functions-legacy/${name}`, 'utf8'));
  }
  const script = `import {createRequire} from 'node:module';
    const m=await import('./${developmentDisplaySource}/lib/index.js');
    const {declaredParams}=createRequire(import.meta.url)('./functions-legacy/node_modules/firebase-functions/lib/params/index.js');
    process.stdout.write(JSON.stringify({names:Object.keys(m), endpoint:m.cloudboardSetDisplayState.__endpoint,params:declaredParams}));`;
  const metadata = JSON.parse(execFileSync(process.execPath, ['--input-type=module', '-e', script], {
    encoding: 'utf8', env: {PATH: process.env.PATH, GCLOUD_PROJECT: 'cloud-board-development'},
  }));
  assert.deepEqual(metadata.names, ['cloudboardSetDisplayState']);
  assert.deepEqual(metadata.params, []);
  assert.deepEqual(metadata.endpoint.region, ['asia-southeast1']);
  assert.equal(metadata.endpoint.minInstances, 0);
  assert.equal(metadata.endpoint.serviceAccountEmail,
    'development-runtime@cloud-board-development.iam.gserviceaccount.com');
  assert.deepEqual(metadata.endpoint.secretEnvironmentVariables ?? [], []);
  assert.throws(() => execFileSync(process.execPath, ['--input-type=module', '-e', script], {
    encoding: 'utf8', env: {PATH: process.env.PATH, GCLOUD_PROJECT: 'cloud-board-stationd'}, stdio: 'pipe',
  }), /development-only/);
  await assert.rejects(prepareDevelopmentDisplayPackage('cloud-board-stationd'), /development-only/);
});
