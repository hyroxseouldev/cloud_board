// Read-only production/development inventory. Never emits tokens, names, email,
// raw account IDs or device IDs. Stable hashes permit comparison across runs.
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getDatabase} from 'firebase-admin/database';
import {getAuth} from 'firebase-admin/auth';
import {resolveDisplayBinding} from '../src/display-recovery.js';

const args = process.argv.slice(2);
const projectId = args[args.indexOf('--project') + 1];
if (args.length !== 2 || args[0] !== '--project' || !['cloud-board-stationd', 'cloud-board-development'].includes(projectId)) {
  throw new Error('Usage: node functions/scripts/inventory-display-connections.mjs --project <explicit project>');
}
const npmRoot = execFileSync('npm', ['root', '-g'], {encoding: 'utf8'}).trim();
const require = createRequire(path.join(npmRoot, 'firebase-tools/package.json'));
const {configstore} = require('./lib/configstore');
const {getAccessToken} = require('./lib/auth');
const refreshToken = configstore.get('tokens')?.refresh_token;
if (!refreshToken) throw new Error('Use firebase login first.');
const credential = {getAccessToken: async () => {
  const saved = configstore.get('tokens');
  const token = saved?.expires_at > Date.now() + 60000 ? saved : await getAccessToken(refreshToken, saved?.scopes);
  return {access_token: token.access_token, expires_in: 3600};
}};
const databaseURL = `https://${projectId}-default-rtdb.asia-southeast1.firebasedatabase.app`;
const app = initializeApp({projectId, databaseURL, credential});
const hash = value => createHash('sha256').update(String(value)).digest('hex').slice(0, 16);
const startedAt = new Date().toISOString();
try {
  const token = await credential.getAccessToken();
  const response = await fetch(`${databaseURL}/users.json?shallow=true`, {
    headers: {Authorization: `Bearer ${token.access_token}`}, signal: AbortSignal.timeout(30000)});
  if (!response.ok) throw new Error(`Read-only inventory failed (${response.status})`);
  const owners = Object.keys(await response.json() || {});
  const database = getDatabase(app), root = {users: {}, displayAccess: (await database.ref('displayAccess').get()).val() || {},
    displayConnectionRevocations: (await database.ref('displayConnectionRevocations').get()).val() || {}};
  for (const owner of owners) root.users[owner] = {devices: (await database.ref(`users/${owner}/devices`).get()).val() || {}};
  const records = [], counts = {};
  const count = status => {counts[status] = (counts[status] || 0) + 1;};
  const auth = getAuth(app);
  for (const [ownerId, user] of Object.entries(root.users)) for (const [deviceId, device] of Object.entries(user.devices)) {
    if (device?.paired !== true && !(device?.paired === undefined && device?.pairedAtMs > 0)) continue;
    const mappings = Object.entries(root.displayAccess).filter(([, a]) => a?.ownerId === ownerId && a.deviceId === deviceId);
    let status = 'healthy', authStatus = 'not_checked';
    if (!device.displayUid && !mappings.length) status = 'legacy_owner_authenticated_or_unproven';
    else {
      try {
        const resolved = resolveDisplayBinding(root, ownerId, deviceId, mappings[0]?.[0]);
        status = resolved.repaired ? 'missing_reverse_uid' : 'healthy';
        try {
          const account = await auth.getUser(resolved.displayUid);
          authStatus = account.disabled ? 'disabled' : account.providerData.length === 0 ? 'anonymous_identity' : 'provider_identity';
          if (account.disabled) status = 'disabled_display_identity';
        } catch (e) {authStatus = e.code === 'auth/user-not-found' ? 'missing_identity' : 'lookup_unavailable';}
      } catch (e) {status = e.details?.code || 'unclassified';}
    }
    count(status);
    records.push({ownerHash: hash(ownerId), deviceHash: hash(deviceId), status, authStatus,
      hasDisplayUid: Boolean(device.displayUid), matchingMappingCount: mappings.length,
      appVersion: typeof device.appVersion === 'string' && /^[0-9A-Za-z.+_-]{1,64}$/.test(device.appVersion) ? device.appVersion : 'unknown',
      recoveryProtocol: device.recoveryProtocol === 1 ? 1 : 0});
  }
  let orphanMappings = 0;
  for (const access of Object.values(root.displayAccess)) if (access?.ownerId &&
      !root.users[access.ownerId]?.devices?.[access.deviceId]) orphanMappings++;
  console.log(JSON.stringify({schemaVersion: 1, mode: 'read_only', projectId, startedAt, completedAt: new Date().toISOString(),
    ownerCount: owners.length, registeredDeviceCount: records.length, counts, orphanMappings,
    causeOfHistoricalMissingUid: 'unconfirmed', records}, null, 2));
} finally {await deleteApp(app);}
