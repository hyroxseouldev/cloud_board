import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import {realpathSync} from 'node:fs';
import {hash, canonical} from './common.mjs';

export function verifyFunctionInventory(inventory, selectors, project) {
  assert.equal(inventory.status, 'success', 'Function inventory did not succeed');
  assert(Array.isArray(inventory.result));
  return selectors.map(selector => {
    const [, codebase, name] = selector.split(':');
    assert(selector.startsWith('functions:') && name);
    const matches = inventory.result.filter(f => f.id === name && f.codebase === codebase);
    assert.equal(matches.length, 1, `Function ${name} was not read back unambiguously`);
    const fn = matches[0]; assert.equal(fn.project, project); assert.equal(fn.state, 'ACTIVE', `Function ${name} is not ACTIVE`);
    return {name, codebase, region: fn.region, state: fn.state, ...(fn.updateTime ? {updateTime: fn.updateTime} : {})};
  });
}
export async function firebaseLoginToken(auth, cwd = process.cwd()) {
  const account = auth.getProjectDefaultAccount(cwd);
  // Firebase CLI grants the Firebase scope, not firebase.database. Requesting
  // an ungranted refresh scope fails before any rules can be read back.
  return (await auth.getAccessToken(account?.tokens?.refresh_token, [
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/firebase',
    'https://www.googleapis.com/auth/userinfo.email',
  ])).access_token;
}
export async function localGoogleRequest(url) {
  let token;
  try {
    const require = createRequire(new URL('../../functions/package.json', import.meta.url));
    const {GoogleAuth} = require('google-auth-library');
    token = await new GoogleAuth({scopes: ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase.database', 'https://www.googleapis.com/auth/userinfo.email']}).getAccessToken();
  } catch {
    // Reuse the existing Firebase CLI login without printing or saving credentials.
    try {
      const binary = execFileSync('which', [process.env.FIREBASE_BIN || 'firebase'], {encoding: 'utf8'}).trim();
      const require = createRequire(realpathSync(binary));
      const auth = require('../auth.js');
      token = await firebaseLoginToken(auth);
    } catch { throw new Error('Rule readback requires existing ADC or Firebase CLI authentication'); }
  }
  assert(token, 'Missing local Google access token');
  const response = await fetch(url, {headers: {Authorization: `Bearer ${token}`}, signal: AbortSignal.timeout(30000)});
  assert(response.ok, `Rule readback failed (HTTP ${response.status})`);
  return response.json();
}
export async function readbackRules({project, files, request = localGoogleRequest}) {
  assert(['cloud-board-development', 'cloud-board-stationd'].includes(project));
  const result = {status: 'success', indexes: 'deployment-command-only', services: {}};
  for (const [service, release, file] of [['firestore', 'cloud.firestore', 'firestore.rules'],
    ['storage', `firebase.storage/${project}.firebasestorage.app`, 'storage.rules']]) {
    const info = await request(`https://firebaserules.googleapis.com/v1/projects/${project}/releases/${release}`);
    assert.match(info.rulesetName || '', new RegExp(`^projects/${project}/rulesets/[A-Za-z0-9-]+$`));
    const rules = await request(`https://firebaserules.googleapis.com/v1/${info.rulesetName}`);
    assert.equal(rules.source?.files?.length, 1);
    assert.equal(hash(rules.source.files[0].content), hash(files[file]), `${service} deployed rules differ from source`);
    result.services[service] = {version: info.rulesetName, sourceHash: hash(files[file])};
  }
  const remote = await request(`https://${project}-default-rtdb.asia-southeast1.firebasedatabase.app/.settings/rules.json`);
  assert.equal(hash(canonical(remote)), hash(canonical(JSON.parse(files['database.rules.json']))), 'RTDB deployed rules differ from source');
  result.services.database = {semanticHash: hash(canonical(remote))};
  return result;
}
