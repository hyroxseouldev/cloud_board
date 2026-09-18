// Dry-run unless --apply. Uses Application Default Credentials, never prints credentials.
import {initializeApp, applicationDefault} from 'firebase-admin/app';
import {getFirestore, FieldValue} from 'firebase-admin/firestore';
import {mkdir, writeFile} from 'node:fs/promises';
import {resolve, join} from 'node:path';
import {randomUUID} from 'node:crypto';
import {legacySettingKeys, planSettings} from '../src/workout-settings-migration.js';
const args = process.argv.slice(2);
const option = key => args.includes(key) ? args[args.indexOf(key) + 1] : null;
const projectId = option('--project');
const uid = option('--uid');
const apply = args.includes('--apply');
const finalize = args.includes('--finalize');
if (!projectId || (projectId !== 'cloud-board-stationd' && !projectId.startsWith('demo-'))) throw Error('Explicit --project required');
if (finalize && !args.includes('--confirm-compatible-clients')) throw Error('Finalize requires verified compatible clients and --confirm-compatible-clients');
const backupRoot = option('--backup-dir');
if (apply && !backupRoot) throw Error('--apply requires --backup-dir');
if (uid && uid.includes('/')) throw Error('Invalid UID');
initializeApp({projectId, ...(process.env.FIRESTORE_EMULATOR_HOST ? {} : {credential: applicationDefault()})});
const db = getFirestore();
const run = `${Date.now()}-${randomUUID()}`;
const backup = apply ? resolve(backupRoot, run) : null;
if (backup) await mkdir(backup, {recursive: true, mode: 0o700});
const references = uid ? [db.doc(`users/${uid}`)] : await db.collection('users').listDocuments();
const report = [];
const sameVersion = (a, b) => a.exists === b.exists && (!a.exists || a.updateTime.isEqual(b.updateTime));
async function writeBackup(name, body) {
  if (!backup) return;
  await writeFile(join(backup, `${name}.json`), JSON.stringify({projectId, run, ...body}, null, 2), {flag: 'wx', mode: 0o600});
}
for (const user of references) {
  const lock = db.doc(`accountDeletions/${user.id}`);
  try {
    if ((await lock.get()).exists) {report.push({uid: user.id, status: 'deleting-skipped'}); continue;}
    const canonicalRef = user.collection('settings').doc('workout');
    const [profile, canonical, workouts] = await Promise.all([user.get(), canonicalRef.get(), user.collection('workouts').get()]);
    const plan = planSettings(profile.data() ?? {}, workouts.docs.map(d => d.data()), canonical.data());
    const row = {uid: user.id, status: plan.status, workouts: workouts.size, variants: plan.variants};
    report.push(row);
    if (plan.status === 'needs-selection') continue;
    if (!apply) continue;
    await writeBackup(user.id, {uid: user.id, profile: profile.data() ?? null, canonical: canonical.data() ?? null,
      profileUpdateTime: profile.updateTime ?? null, canonicalUpdateTime: canonical.updateTime ?? null,
      workouts: workouts.docs.map(d => ({id: d.id, updateTime: d.updateTime, data: d.data()}))});
    // Query inside transaction detects edits/additions during inference.
    await db.runTransaction(async tx => {
      const deletion = await tx.get(lock);
      const currentProfile = await tx.get(user);
      const currentSettings = await tx.get(canonicalRef);
      const currentWorkouts = await tx.get(user.collection('workouts'));
      if (deletion.exists) throw Error('Account deletion started');
      if (!sameVersion(profile, currentProfile) || !sameVersion(canonical, currentSettings) ||
          currentWorkouts.size !== workouts.size || currentWorkouts.docs.some(d => {
            const old = workouts.docs.find(w => w.id === d.id); return !old || !sameVersion(old, d);
          })) throw Error('Data changed after backup; rerun dry-run');
      if (!canonical.exists) tx.create(canonicalRef, {schemaVersion: 1, revision: 1, updatedAt: FieldValue.serverTimestamp(),
        contentOnly: finalize, preferences: plan.preferences});
      else if (finalize && canonical.data().contentOnly !== true) tx.update(canonicalRef, {
        contentOnly: true, revision: canonical.data().revision + 1, updatedAt: FieldValue.serverTimestamp()});
      if (!finalize && !canonical.exists) tx.set(user, {uid: user.id, workoutSettings: plan.preferences}, {merge: true});
    });
    row.status = finalize ? 'content-only-activated' : 'prepared';
    if (!finalize) continue;
    // Marker protects against old clients recreating removed fields. Per-doc
    // transactions preserve concurrent content edits; each exact source is backed up.
    for (const reference of await user.collection('workouts').listDocuments()) {
      const original = await reference.get();
      if (!original.exists || (original.data().schemaVersion === 2 && !legacySettingKeys.some(k => k in original.data()))) continue;
      await writeBackup(`${user.id}-${randomUUID()}`, {uid: user.id, workoutId: reference.id,
        updateTime: original.updateTime, data: original.data()});
      await db.runTransaction(async tx => {
        const deletion = await tx.get(lock);
        const current = await tx.get(reference);
        const settings = await tx.get(canonicalRef);
        if (deletion.exists || settings.data()?.contentOnly !== true || !sameVersion(original, current)) throw Error('Changed during cleanup; safely rerun');
        tx.update(reference, {schemaVersion: 2, ...Object.fromEntries(legacySettingKeys.map(k => [k, FieldValue.delete()]))});
      });
    }
    await db.runTransaction(async tx => {
      const deletion = await tx.get(lock);
      const current = await tx.get(user);
      const settings = await tx.get(canonicalRef);
      if (deletion.exists || settings.data()?.contentOnly !== true) throw Error('Cleanup state changed');
      if (current.exists) tx.update(user, {workoutSettings: FieldValue.delete(), countdownDefaults: FieldValue.delete()});
    });
    row.status = 'finalized';
  } catch (error) {
    report.push({uid: user.id, status: 'error', message: error.message});
    process.exitCode = 1;
  }
}
if (backup) await writeBackup('report', {report});
console.log(JSON.stringify({mode: apply ? 'apply' : 'dry-run', finalize, report}, null, 2));
await db.terminate();
