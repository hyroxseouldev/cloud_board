import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {GoogleAuth} from 'google-auth-library';
import {targets} from '../../tool/firebase/release.mjs';
import {readJson, writeJson, hash, canonical} from '../../tool/firebase/common.mjs';

export async function verifyLiveRules(manifest, request) {
  assert.deepEqual(manifest.targets, targets, 'Wrong live-rule target');
  const services = {};
  for (const [service, release, file] of [
    ['firestore', 'cloud.firestore', 'firestore.rules'],
    ['storage', `firebase.storage/${targets.storage}`, 'storage.rules'],
  ]) {
    const info = await request(`https://firebaserules.googleapis.com/v1/projects/${targets.project}/releases/${release}`);
    assert.match(info.data.rulesetName || '', new RegExp(`^projects/${targets.project}/rulesets/[A-Za-z0-9-]+$`));
    const ruleset = await request(`https://firebaserules.googleapis.com/v1/${info.data.rulesetName}`);
    assert.equal(ruleset.data.source?.files?.length, 1, 'Unexpected ruleset sources');
    const sourceHash = hash(ruleset.data.source.files[0].content);
    assert.equal(sourceHash, manifest.files[file], `${service} deployed rules differ from verified source`);
    services[service] = {sourceHash, version: info.data.rulesetName, updateTime: info.data.updateTime};
  }
  const remote = await request(`${targets.databaseURL}/.settings/rules.json`);
  assert.equal(hash(canonical(remote.data)), manifest.databaseSemanticHash, 'Database deployed rules differ from verified source');
  services.database = {sourceHash: manifest.files['database.rules.json'], semanticHash: hash(canonical(remote.data)),
    version: remote.headers?.etag || hash(canonical(remote.data))};
  return {format: 1, status: 'success', checkedAt: new Date().toISOString(), services};
}
export async function googleRequest(url) {
  const auth = new GoogleAuth({scopes: ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase.database', 'https://www.googleapis.com/auth/userinfo.email']});
  const client = await auth.getClient();
  return client.request({url, timeout: 30_000});
}
export async function waitForLiveRules(manifest, request, {attempts = 12, sleep = ms => new Promise(resolve => setTimeout(resolve, ms))} = {}) {
  for (let attempt = 1; ; attempt++) {
    try { return await verifyLiveRules(manifest, request); }
    catch (error) {
      if (attempt >= attempts || error.name !== 'AssertionError' || !error.message.includes('deployed rules differ')) throw error;
      await sleep(5000);
    }
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const manifest = readJson(process.argv[2] || 'build/release/manifest.json');
    const result = process.argv.includes('--wait') ? await waitForLiveRules(manifest, googleRequest) : await verifyLiveRules(manifest, googleRequest);
    writeJson('build/release/live-rules.json', result);
    console.log('Verified Firestore, RTDB and Storage deployment versions.');
  } catch (error) {
    // Do not print Gaxios request objects or bearer headers.
    writeJson('build/release/live-rules.json', {format: 1, status: 'failure', checkedAt: new Date().toISOString(),
      reason: error.name === 'AssertionError' ? error.message : `Rules read-back failed (${error.response?.status || error.code || 'unknown'})`});
    console.error('Rules read-back failed; see sanitized live-rules.json.');
    process.exitCode = 1;
  }
}
