// Read-only by default. --apply requires --backup-dir and the exact project ID.
// Originals are retained: workouts stay in place; running/legacy sessions are
// never rewritten. Backfill creates summaries and immutable snapshot copies.
import {initializeApp} from 'firebase-admin/app';
import {Firestore} from '@google-cloud/firestore';

import {getDatabase} from 'firebase-admin/database';
import {mkdir, writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
import {backfillCatalog, summarizeWorkout} from '../src/workout-catalog.js';
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
const realtime = getDatabase(app);
const stats = {mode: apply ? 'apply' : 'dry-run', accounts: 0, workouts: 0, summaryBytes: 0,
  detailBytes: 0, legacySessionBytes: 0, splitStateBytes: 0, snapshotCopies: 0, activeSessionsPreserved: 0, deletingAccountsSkipped: 0};
if (!projectId.startsWith('demo-')) {
  const token = await config.credential.getAccessToken();
  const response = await fetch(`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)`,
    {headers: {Authorization: `Bearer ${token.access_token}`}});
  if (!response.ok) throw new Error(`Database metadata: HTTP ${response.status}`);
  const metadata = await response.json();
  stats.firestoreLocation = metadata.locationId;
}
console.error('Migration: enumerate accounts');
const users = await db.collection('users').listDocuments();
console.error(`Migration: inspecting ${users.length} account(s)`);
for (const user of users) {
  console.error('Migration: check deletion lock');
  if ((await db.doc(`accountDeletions/${user.id}`).get()).exists) {
    stats.deletingAccountsSkipped++; continue;
  }
  console.error('Migration: read workout catalog');
  const workouts = await user.collection('workouts').get();
  const summaries = await user.collection('workoutSummaries').get();
  const marker = await user.collection('catalog').doc('schema').get();
  const sessionRef = realtime.ref(`users/${user.id}/activeSession`);
  console.error('Migration: read realtime session');
  const session = (await sessionRef.get()).val();
  stats.accounts++;
  const data = workouts.docs.map(doc => ({id: doc.id, data: doc.data()}));
  for (const doc of data) {
    const summary = summarizeWorkout(doc.data, doc.id); // Validate before writes.
    stats.workouts++;
    stats.detailBytes += Buffer.byteLength(JSON.stringify(doc.data));
    stats.summaryBytes += Buffer.byteLength(JSON.stringify(summary));
  }
  if (session && session.status !== 'completed') stats.activeSessionsPreserved++;
  if (apply) {
    // Exclusive file creation prevents overwriting a prior recovery point.
    await writeFile(path.join(backupDir, `${user.id}.json`), JSON.stringify({
      version: 1, projectId, uid: user.id, backedUpAt: new Date().toISOString(),
      workouts: data, summaries: summaries.docs.map(doc => ({id: doc.id, data: doc.data()})),
      marker: marker.data() || null, activeSession: session,
    }), {mode: 0o600, flag: 'wx'});
    await backfillCatalog(db, user.id);
    // Transactional latest reads above are authoritative. Recheck projections
    // for every current source before reporting success.
    const current = await user.collection('workouts').get();
    for (const doc of current.docs) {
      const summary = await user.collection('workoutSummaries').doc(doc.id).get();
      if (JSON.stringify(summary.data()) !== JSON.stringify(summarizeWorkout(doc.data(), doc.id))) {
        // Firestore property order is not stable; compare fields individually.
        const expected = summarizeWorkout(doc.data(), doc.id);
        for (const [key, value] of Object.entries(expected)) {
          if (key === 'updatedAt' ? !summary.data()?.[key]?.isEqual(value) : summary.data()?.[key] !== value) {
            throw new Error('Projection changed during verification; safely rerun in a new backup directory.');
          }
        }
      }
    }
  }
  // Safe additive preparation even for a live v1 session; no active pointer or
  // state is changed. New v2 sessions are created only by capable app versions.
  if (session?.workoutSnapshot && session.id) {
    stats.legacySessionBytes += Buffer.byteLength(JSON.stringify(session));
    const split = {...session, schemaVersion: 2, snapshotId: session.id,
      workoutId: session.workoutSnapshot.id, workoutName: session.workoutSnapshot.name};
    delete split.workoutSnapshot;
    stats.splitStateBytes += Buffer.byteLength(JSON.stringify(split));
    if (apply && !(await db.doc(`accountDeletions/${user.id}`).get()).exists) {
      const snapshotRef = realtime.ref(`users/${user.id}/playbackSnapshots/${session.id}`);
      await snapshotRef.transaction(value => value === null ? {...session.workoutSnapshot, _storedAtMs: Date.now()} : undefined);
    }
    stats.snapshotCopies++;
  }
}
console.log(JSON.stringify(stats, null, 2));
process.exit(0);
