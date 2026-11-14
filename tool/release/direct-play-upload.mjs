import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {googleToken, packageName} from './play_version_code.mjs';

export async function uploadInternal({artifact, versionCode, token, request = fetch}) {
  assert.match(String(versionCode), /^[1-9]\d*$/);
  const base = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}`;
  const send = async (url, method, body, binary = false) => {
    const response = await request(url, {method, headers: {Authorization: `Bearer ${token}`,
      'Content-Type': binary ? 'application/octet-stream' : 'application/json'},
    ...(body !== undefined ? {body: binary ? body : JSON.stringify(body)} : {}), signal: AbortSignal.timeout(300000)});
    assert(response.ok, `Play ${method} failed (HTTP ${response.status}); upload/commit remains unconfirmed`);
    return response.status === 204 ? null : response.json();
  };
  const edit = await send(`${base}/edits`, 'POST', {});
  assert.match(edit.id || '', /^[A-Za-z0-9_-]+$/);
  let committed = false;
  try {
    const bundle = await send(`https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${packageName}/edits/${edit.id}/bundles?uploadType=media`, 'POST', artifact, true);
    assert.equal(String(bundle.versionCode), String(versionCode), 'Uploaded bundle code differs from reservation');
    await send(`${base}/edits/${edit.id}/tracks/internal`, 'PUT', {track: 'internal', releases: [{status: 'completed', versionCodes: [String(versionCode)]}]});
    await send(`${base}/edits/${edit.id}:validate`, 'POST');
    await send(`${base}/edits/${edit.id}:commit`, 'POST'); committed = true;
    return {status: 'uploaded', track: 'internal', versionCode: String(versionCode), review: 'unverified'};
  } finally {
    if (!committed) { try { await send(`${base}/edits/${edit.id}`, 'DELETE'); } catch { /* Retain failed/unknown receipt, never retry commit automatically. */ } }
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  assert.equal(process.env.GOOGLE_PLAY_BOOTSTRAPPED, 'true', 'Confirm initialized Play application before uploading');
  const token = await googleToken(JSON.parse(process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON || '{}'));
  console.log(JSON.stringify(await uploadInternal({artifact: readFileSync(process.argv[2]), versionCode: process.argv[3], token})));
}
