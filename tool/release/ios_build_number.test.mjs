import assert from 'node:assert/strict';
import test from 'node:test';
import {highestIosBuild, inventoryIos} from './ios_build_number.mjs';
test('iOS uses highest actual build, not most recent upload or Android numbering', () => {
  assert.equal(highestIosBuild([{attributes: {version: '551'}}, {attributes: {version: '553'}}, {attributes: {version: '548'}}]), 553);
  assert.throws(() => highestIosBuild([]));
  assert.throws(() => highestIosBuild([{attributes: {version: '1.2'}}]));
});
test('iOS traverses all history pages and refuses foreign pagination', async () => {
  let calls = 0;
  const request = async () => ({ok: true, json: async () => {
    calls += 1;
    return [null, {data: [{id: '6809105126'}]}, {data: [{attributes: {version: '551'}}], links: {next: 'https://api.appstoreconnect.apple.com/v1/builds?cursor=2'}},
      {data: [{attributes: {version: '553'}}]}][calls];
  }});
  assert.deepEqual(await inventoryIos('test-only', request), {appId: '6809105126', highestBuild: 553, observedBuildCount: 2});
  await assert.rejects(inventoryIos('test-only', async url => ({ok: true, json: async () => url.includes('/apps?') ? {data: [{id: '1'}]} : {data: [], links: {next: 'https://attacker.invalid/v1/builds'}}})), /pagination/);
});

test('development iOS allocation reads only the distinct bundle and permits its first build', async () => {
  const seen = [];
  const inventory = await inventoryIos('test-only', async url => {
    seen.push(url);
    return {ok: true, json: async () => url.includes('/apps?') ? {data: [{id: '123'}]} : {data: []}};
  }, 'com.sunmkim.cloudboard.dev');
  assert.match(seen[0], /com.sunmkim.cloudboard.dev/);
  assert.equal(inventory.highestBuild, 0);
  await assert.rejects(inventoryIos('test-only', async () => {throw new Error('must not request');}, 'other.bundle'), /Unexpected iOS bundle/);
});
