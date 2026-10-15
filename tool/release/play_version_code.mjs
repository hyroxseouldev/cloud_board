import assert from 'node:assert/strict';
import {createSign} from 'node:crypto';
import {readFileSync, writeFileSync, appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

export const packageName = process.env.ANDROID_PACKAGE_NAME || 'com.sunmkim.cloudboard';
assert(['com.sunmkim.cloudboard', 'com.sunmkim.cloudboard.dev'].includes(packageName), 'Unexpected Android package');
export const reservationPrefix = `refs/tags/play-version-code${packageName.endsWith('.dev') ? '-development' : ''}/`;
const reservationPath = reservationPrefix.slice('refs/'.length);
const publisher = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}`;
const maxCode = 2100000000;
const integer = value => {
  assert(/^[1-9]\d*$/.test(String(value)), 'Invalid Play versionCode');
  const n = Number(value);
  assert(Number.isSafeInteger(n) && n <= maxCode, 'Play versionCode exceeds supported range');
  return n;
};
export function versionName(pubspec) {
  const matches = [...pubspec.matchAll(/^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$/gm)];
  assert.equal(matches.length, 1, 'Expected exactly one semantic app version in pubspec');
  return matches[0][1];
}
export function currentStoreCodes({tracks, bundles, apks}) {
  assert(Array.isArray(tracks?.tracks), 'Play track inventory is missing');
  // Empty bundle/APK lists omit the corresponding property in this API.
  for (const [data, field] of [[bundles, 'bundles'], [apks, 'apks']]) {
    assert(data && typeof data === 'object' && (!data[field] || Array.isArray(data[field])), `Invalid Play ${field} inventory`);
  }
  return [...new Set([
    ...tracks.tracks.flatMap(track => (track.releases ?? []).flatMap(release => release.versionCodes ?? [])),
    ...(bundles.bundles ?? []).map(bundle => bundle.versionCode),
    ...(apks.apks ?? []).map(apk => apk.versionCode),
  ].map(integer))].sort((a, b) => a - b);
}
export function validateBaseline(baseline, {now = Date.now(), hasReservations = false} = {}) {
  assert.equal(baseline.packageName, packageName, 'Wrong baseline package');
  assert.equal(baseline.completeUploadHistory, true, 'Complete Play Console upload history must be verified before allocation');
  assert.equal(baseline.manualUploadPolicy, 'reserve-with-this-allocator', 'Manual uploads must reserve a new code with this allocator');
  integer(baseline.highestEverVersionCode);
  assert(typeof baseline.verifiedBy === 'string' && baseline.verifiedBy.trim(), 'Missing baseline verifier');
  assert(/^https:\/\/play\.google\.com\/console\//.test(baseline.evidenceUrl ?? ''), 'Missing Play Console history evidence');
  const age = now - Date.parse(baseline.verifiedAt);
  assert(Number.isFinite(age) && age >= 0, 'Invalid baseline verification time');
  if (!hasReservations) assert(age <= 24 * 60 * 60 * 1000, 'First reservation needs full upload-history verification within 24 hours');
  return baseline.highestEverVersionCode;
}
export function nextCode({storeCodes, reservedCodes, baseline}, options) {
  const floor = validateBaseline(baseline, {...options, hasReservations: reservedCodes.length > 0});
  const previous = Math.max(floor, 0, ...storeCodes.map(integer), ...reservedCodes.map(integer));
  return integer(previous + 1);
}
async function checkedFetch(url, options = {}) {
  const response = await fetch(url, {...options, signal: AbortSignal.timeout(30000)});
  if (!response.ok) {
    const error = new Error(`Release metadata request failed: HTTP ${response.status} (${new URL(url).hostname})`);
    error.status = response.status;
    throw error;
  }
  return response.status === 204 ? null : response.json();
}
export async function googleToken(account) {
  assert.equal(account.type, 'service_account', 'Play service account is required');
  assert(account.client_email && account.private_key, 'Incomplete Play credential');
  const b64 = data => Buffer.from(JSON.stringify(data)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const payload = `${b64({alg: 'RS256', typ: 'JWT'})}.${b64({iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600})}`;
  const jwt = `${payload}.${createSign('RSA-SHA256').update(payload).sign(account.private_key, 'base64url')}`;
  const result = await checkedFetch('https://oauth2.googleapis.com/token', {method: 'POST',
    body: new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt})});
  assert(result.access_token, 'Play access token missing');
  return result.access_token;
}
export async function playInventory(token, request = checkedFetch) {
  const headers = {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'};
  // An uncommitted edit gives a consistent view. Never upload or commit it.
  const edit = await request(`${publisher}/edits`, {method: 'POST', headers, body: '{}'});
  assert(edit.id && /^\d+$/.test(edit.id), 'Invalid Play edit');
  try {
    const [tracks, bundles, apks] = await Promise.all(['tracks', 'bundles', 'apks'].map(type => request(`${publisher}/edits/${edit.id}/${type}`, {headers})));
    return {packageName, observedAt: new Date().toISOString(), scope: 'current-tracks-bundles-apks',
      currentVersionCodes: currentStoreCodes({tracks, bundles, apks}), tracks: tracks.tracks};
  } finally {
    await request(`${publisher}/edits/${edit.id}`, {method: 'DELETE', headers});
  }
}
export async function reserveCode({inventory, baseline, repository, sha, githubToken, request = checkedFetch}) {
  assert(/^[\w.-]+\/[\w.-]+$/.test(repository), 'Invalid GitHub repository');
  assert(/^[0-9a-f]{40}$/.test(sha), 'Allocation needs the exact source SHA');
  assert(githubToken, 'Missing GitHub reservation credential');
  const base = `https://api.github.com/repos/${repository}/git`;
  const headers = {Authorization: `Bearer ${githubToken}`, Accept: 'application/vnd.github+json', 'Content-Type': 'application/json'};
  for (let retry = 0; retry < 5; retry += 1) {
    const refs = await request(`${base}/matching-refs/${reservationPath}`, {headers});
    assert(Array.isArray(refs), 'Could not verify prior versionCode reservations');
    const reservedCodes = refs.map(ref => {
      assert(ref.ref.startsWith(reservationPrefix), 'Unexpected reservation ref');
      return integer(ref.ref.slice(reservationPrefix.length));
    });
    const code = nextCode({storeCodes: inventory.currentVersionCodes, reservedCodes, baseline});
    const ref = `${reservationPrefix}${code}`;
    try {
      const created = await request(`${base}/refs`, {method: 'POST', headers, body: JSON.stringify({ref, sha})});
      assert.equal(created.ref, ref);
      assert.equal(created.object?.sha, sha);
      return {versionCode: code, reservationRef: ref, sourceSha: sha, repository,
        allocatedAt: new Date().toISOString(), storeObservation: inventory, baseline};
    } catch (error) {
      if (![409, 422].includes(error.status)) throw error;
      // Retry only a genuine competing reservation; auth/schema failures stay fatal.
      const existing = await request(`${base}/ref/${reservationPath}${code}`, {headers});
      assert.equal(existing.ref, ref, 'Reservation conflict was not a competing allocation');
    }
  }
  throw new Error('Could not reserve a unique Play versionCode after 5 attempts');
}
export async function recheckReservation(receipt, token, githubToken) {
  assert.equal(receipt.sourceSha, process.env.SOURCE_SHA || process.env.GITHUB_SHA, 'Reservation belongs to another commit');
  assert.equal(receipt.repository, process.env.GITHUB_REPOSITORY, 'Reservation belongs to another repository');
  const code = integer(receipt.versionCode);
  assert.equal(receipt.reservationRef, `${reservationPrefix}${code}`);
  const ref = await checkedFetch(`https://api.github.com/repos/${receipt.repository}/git/ref/${reservationPath}${code}`,
    {headers: {Authorization: `Bearer ${githubToken}`, Accept: 'application/vnd.github+json'}});
  assert.equal(ref.object?.sha, receipt.sourceSha, 'Reservation was removed or changed');
  const inventory = await playInventory(token);
  assert(inventory.currentVersionCodes.length > 0, 'Empty Play history cannot authorize upload');
  assert(Math.max(...inventory.currentVersionCodes) < code, 'Play advanced after allocation; rebuild with a fresh reserved code');
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const mode = process.argv[2];
  assert(['--inventory-only', '--reserve', '--recheck', '--version-name'].includes(mode), 'Unknown Play release command');
  if (mode === '--version-name') {
    const name = versionName(readFileSync('pubspec.yaml', 'utf8'));
    if (process.env.GITHUB_ENV) appendFileSync(process.env.GITHUB_ENV, `RELEASE_VERSION_NAME=${name}\n`);
    console.log(name);
  } else {
    const token = await googleToken(JSON.parse(process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON || '{}'));
    if (mode === '--recheck') {
      await recheckReservation(JSON.parse(readFileSync(process.argv[3], 'utf8')), token, process.env.GITHUB_TOKEN);
      console.log('Play upload history and unique reservation rechecked.');
    } else {
      const inventory = await playInventory(token);
      if (mode === '--inventory-only') console.log(JSON.stringify(inventory, null, 2));
      else {
        const baseline = JSON.parse(readFileSync(`tool/release/play-version-code-baseline${packageName.endsWith('.dev') ? '-development' : ''}.json`, 'utf8'));
        const receipt = await reserveCode({inventory, baseline, repository: process.env.GITHUB_REPOSITORY,
          sha: process.env.SOURCE_SHA || process.env.GITHUB_SHA, githubToken: process.env.GITHUB_TOKEN});
        receipt.githubRunId = process.env.GITHUB_RUN_ID;
        receipt.githubRunAttempt = process.env.GITHUB_RUN_ATTEMPT;
        assert(process.argv[3], 'Reservation receipt path is required');
        writeFileSync(process.argv[3], `${JSON.stringify(receipt, null, 2)}\n`);
        if (process.env.GITHUB_ENV) appendFileSync(process.env.GITHUB_ENV, `PLAY_BUILD_NUMBER=${receipt.versionCode}\n`);
        console.log(`Reserved Play versionCode ${receipt.versionCode}; never delete or reuse ${receipt.reservationRef}.`);
      }
    }
  }
}
