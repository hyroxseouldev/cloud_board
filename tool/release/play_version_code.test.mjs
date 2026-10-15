import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {versionName, currentStoreCodes, nextCode, reserveCode, playInventory, reservationPrefix} from './play_version_code.mjs';
const baseline = {packageName: 'com.sunmkim.cloudboard', highestEverVersionCode: 65,
  completeUploadHistory: true, verifiedAt: new Date().toISOString(), verifiedBy: 'release operator',
  evidenceUrl: 'https://play.google.com/console/app/bundle-explorer-selector', manualUploadPolicy: 'reserve-with-this-allocator'};
test('version names come from pubspec, separate from store build numbering', () => {
  assert.equal(versionName('name: cloud_board\nversion: 1.1.0+2\n'), '1.1.0');
  assert.throws(() => versionName('version: 1.1.0'));
});
test('inventory includes mobile, TV and non-track bundles/APKs', () => {
  assert.deepEqual(currentStoreCodes({tracks: {tracks: [{track: 'internal', releases: [{versionCodes: ['65']}]},
    {track: 'wear:production', releases: [{versionCodes: ['61']}]}]}, bundles: {bundles: [{versionCode: 69}]}, apks: {apks: [{versionCode: 70}]}}), [61, 65, 69, 70]);
  assert.throws(() => currentStoreCodes({tracks: {}, bundles: {}, apks: {}}));
});
test('reruns and unuploaded manual builds consume unique monotonically increasing reservations', () => {
  assert.equal(nextCode({storeCodes: [65], reservedCodes: [], baseline}), 66);
  assert.equal(nextCode({storeCodes: [65], reservedCodes: [66, 67], baseline}), 68);
  assert.equal(nextCode({storeCodes: [81], reservedCodes: [66, 67], baseline}), 82);
});
test('unverified, stale initial history and exhausted numbers fail closed', () => {
  const input = {storeCodes: [65], reservedCodes: [], baseline};
  assert.throws(() => nextCode({...input, baseline: {...baseline, completeUploadHistory: false}}));
  assert.throws(() => nextCode(input, {now: Date.now() + 25 * 3600000}));
  assert.throws(() => nextCode({...input, reservedCodes: [2100000000]}));
  assert.throws(() => nextCode({...input, baseline: {...baseline, packageName: 'other.app'}}));
});
test('concurrent reservations retry only proven conflicts; rerun never reuses prior ref', async () => {
  let codes = [];
  const request = async (url, options = {}) => {
    if (url.includes('matching-refs')) return codes.map(code => ({ref: `${reservationPrefix}${code}`}));
    if (options.method === 'POST') {
      const {ref, sha} = JSON.parse(options.body);
      const code = Number(ref.split('/').at(-1));
      if (!codes.length) { codes.push(code); throw Object.assign(new Error('conflict'), {status: 422}); }
      codes.push(code); return {ref, object: {sha}};
    }
    return {ref: `${reservationPrefix}${codes.at(-1)}`};
  };
  const receipt = await reserveCode({inventory: {currentVersionCodes: [65]}, baseline,
    repository: 'owner/repo', sha: 'a'.repeat(40), githubToken: 'test-only', request});
  assert.equal(receipt.versionCode, 67);
  assert.deepEqual(codes, [66, 67]);
});
test('inventory edit is always discarded, including partial read failure', async () => {
  const methods = [];
  await assert.rejects(playInventory('test-only', async (url, options) => {
    methods.push(options.method ?? 'GET');
    if (options.method === 'POST') return {id: '123'};
    if (options.method === 'DELETE') return null;
    throw new Error('read failed');
  }));
  assert.equal(methods.at(-1), 'DELETE');
  assert(!methods.includes('PUT'));
});
test('development Play numbering uses its own package, history and reservation namespace', () => {
  const module = new URL('./play_version_code.mjs', import.meta.url).href;
  const code = `import assert from 'node:assert/strict';
    import {packageName, reservationPrefix, validateBaseline, playInventory} from ${JSON.stringify(module)};
    assert.equal(packageName, 'com.sunmkim.cloudboard.dev');
    assert.equal(reservationPrefix, 'refs/tags/play-version-code-development/');
    assert.throws(() => validateBaseline({packageName: 'com.sunmkim.cloudboard'}), /Wrong baseline/);
    await playInventory('test', async (url, options) => {
      assert(url.includes('/applications/com.sunmkim.cloudboard.dev/'));
      if (options.method === 'POST') return {id: '1'};
      if (options.method === 'DELETE') return null;
      return url.endsWith('/tracks') ? {tracks: []} : {};
    });`;
  execFileSync(process.execPath, ['--input-type=module', '-e', code], {
    env: {...process.env, ANDROID_PACKAGE_NAME: 'com.sunmkim.cloudboard.dev'}, stdio: 'pipe',
  });
});
