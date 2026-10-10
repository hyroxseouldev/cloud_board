import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {verifyLiveRules, waitForLiveRules} from '../../functions/tools/live-rules.mjs';
import {receiptFor} from './test-fixtures.mjs';
const request = async url => {
  if (url.endsWith('/.settings/rules.json')) return {data: JSON.parse(readFileSync('database.rules.json', 'utf8'))};
  if (url.includes('/releases/')) return {data: {rulesetName: `projects/cloud-board-stationd/rulesets/${url.includes('cloud.firestore') ? 'firestore' : 'storage'}`}};
  return {data: {source: {files: [{content: readFileSync(url.endsWith('firestore') ? 'firestore.rules' : 'storage.rules', 'utf8')}]}}};
};
test('deployed versions match exact source and normalized RTDB JSON', async () => {
  const result = await verifyLiveRules(receiptFor().manifest, request);
  assert.equal(result.status, 'success'); assert.equal(Object.keys(result.services).length, 3);
});
test('drift, wrong project and inaccessible rules never become green', async () => {
  await assert.rejects(verifyLiveRules(receiptFor().manifest, async url => url.endsWith('/.settings/rules.json') ? {data: {rules: {'.read': true}}} : request(url)), /differ/);
  await assert.rejects(verifyLiveRules(receiptFor().manifest, async url => url.includes('/rulesets/') ? {data: {source: {files: [{content: 'changed'}]}}} : request(url)), /differ/);
  await assert.rejects(verifyLiveRules({...receiptFor().manifest, targets: {}}, request));
  await assert.rejects(verifyLiveRules(receiptFor().manifest, async () => {throw new Error('403');}));
});
test('propagation retries are bounded and never mask API permission failures', async () => {
  let stale = true, sleeps = 0;
  const delayed = async url => url.endsWith('/.settings/rules.json') && stale ? {data: {rules: {'.read': false}}} : request(url);
  const result = await waitForLiveRules(receiptFor().manifest, delayed, {attempts: 2, sleep: async () => { sleeps++; stale = false; }});
  assert.equal(result.status, 'success'); assert.equal(sleeps, 1);
  stale = true; sleeps = 0;
  await assert.rejects(waitForLiveRules(receiptFor().manifest, delayed, {attempts: 2, sleep: async () => { sleeps++; }}), /differ/);
  assert.equal(sleeps, 1);
  await assert.rejects(waitForLiveRules(receiptFor().manifest, async () => { throw new Error('403'); }, {sleep: async () => { throw new Error('Must not retry a permission error'); }}), /403/);
});
