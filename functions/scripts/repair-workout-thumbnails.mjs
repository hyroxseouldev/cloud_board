// STA-14: audit by default; --apply requires a private backup directory.
import {initializeApp} from 'firebase-admin/app';
import {Firestore} from '@google-cloud/firestore';

import {randomUUID} from 'node:crypto';
import {mkdir, writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
import {repairWorkoutThumbnail} from '../src/workout-thumbnail-repair.js';
// Use the auth major bundled with Firestore's gax transport (v9 returns a
// header object; v10 Headers cannot be spread by this gax version).
const {OAuth2Client, GoogleAuth} = createRequire(import.meta.resolve('google-gax'))('google-auth-library');
const args = process.argv.slice(2);
const option = name => args[args.indexOf(name) + 1];
const apply = args.includes('--apply');
const projectId = args.includes('--project') ? option('--project') : '';
if (projectId !== 'cloud-board-stationd' && !projectId.startsWith('demo-')) {
  throw new Error('Provide --project cloud-board-stationd (or a demo emulator project).');
}
const backupDir = args.includes('--backup-dir') ? path.resolve(option('--backup-dir')) : null;
if (apply && !backupDir) throw new Error('--apply requires --backup-dir');
if (apply && backupDir) await mkdir(backupDir, {recursive: true, mode: 0o700});
const config = {projectId, databaseURL: `https://${projectId}-default-rtdb.asia-southeast1.firebasedatabase.app`};
if (!projectId.startsWith('demo-')) {
  const npmRoot = execFileSync('npm', ['root', '-g'], {encoding: 'utf8'}).trim();
  const require = createRequire(path.join(npmRoot, 'firebase-tools/package.json'));
  const {configstore} = require('./lib/configstore');
  const {getAccessToken} = require('./lib/auth');
  const refreshToken = configstore.get('tokens')?.refresh_token;
  if (!refreshToken) throw new Error('Use firebase login first.');
  config.credential = {getAccessToken: async () => {
    const saved = configstore.get('tokens');
    const token = saved?.expires_at > Date.now() + 60000 ? saved : await getAccessToken(refreshToken, saved?.scopes);
    return {access_token: token.access_token, expires_in: 3600};
  }};
}
const app = initializeApp(config);
let authClient;
if (config.credential) {
  authClient = new OAuth2Client();
  authClient.refreshHandler = async () => {
    const token = await config.credential.getAccessToken();
    return {access_token: token.access_token, expiry_date: Date.now() + 3500000};
  };
  authClient.setCredentials(await authClient.refreshHandler());
}
const db = new Firestore({projectId, preferRest: true, ...(authClient ? {auth: new GoogleAuth({authClient})} : {})});

const stats = {mode: apply ? 'apply' : 'dry-run', accounts: 0, checked: 0, candidate: 0, repaired: 0, unchanged: 0, skipped: 0};
const backup = async value => {
  await writeFile(path.join(backupDir, `${randomUUID()}.json`), JSON.stringify({
    projectId, backedUpAt: new Date().toISOString(), ...value,
  }), {mode: 0o600, flag: 'wx'});
};
try {
  for (const user of await db.collection('users').listDocuments()) {
    stats.accounts++;
    let cursor;
    do {
      let query = user.collection('workouts').orderBy('__name__').limit(100);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const doc of page.docs) {
        stats.checked++;
        stats[await repairWorkoutThumbnail(db, user.id, doc.id, {apply, backup})]++;
      }
      cursor = page.docs.at(-1);
      if (page.size < 100) break;
    } while (cursor);
  }
  console.log(JSON.stringify(stats, null, 2));
} finally {
  await db.terminate();
}
