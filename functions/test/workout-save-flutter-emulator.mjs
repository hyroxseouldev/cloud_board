import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {planAccess} from '../src/plan-policy.js';

for (const name of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST',
  'FIREBASE_STORAGE_EMULATOR_HOST', 'STA189_FUNCTIONS_EMULATOR_HOST']) {
  assert.match(process.env[name] ?? '', /^127\.0\.0\.1:\d+$/, `${name} must be local`);
}
const projectId = process.env.GCLOUD_PROJECT;
assert.equal(projectId, 'demo-cloudboard-sta189-callable');
const app = initializeApp({projectId}), db = getFirestore(app);
const uid = 'sta189-chrome-owner', centerId = 'sta189-chrome-center';
try {
  await getAuth(app).createUser({uid, email: 'sta189-chrome@example.test',
    password: 'local-emulator-only', displayName: 'Local browser probe'});
  await db.doc(`subscriptionEntitlements/${uid}`).set({
    ...planAccess('free'), plan: 'free', status: 'active',
    validUntilMs: Date.now() + 86400000,
  });
  await db.doc(`centers/${centerId}`).set({ownerUid: uid});
  await db.doc(`centers/${centerId}/slideTemplateCatalog/current`).set({
    schemaVersion: 1, revision: 1, centerName: '', templates: [{
      id: 'local-plain', name: 'Local template', description: '', sortOrder: 0, published: true,
      recipe: {schemaVersion: 1, templateId: 'local-plain', revision: 1, centerId,
        width: 16, height: 9, backgroundColor: 0xff173c30, fields: []},
    }],
  });
  const child = spawn(process.env.FLUTTER_BIN ?? 'flutter', [
    'test', '--platform', 'chrome', '--dart-define=STA189_LOCAL_EMULATORS=true',
    'test/manual/workout_save_emulator_probe.dart', '--reporter', 'expanded',
  ], {cwd: fileURLToPath(new URL('../../', import.meta.url)), stdio: 'inherit'});
  const exitCode = await new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('exit', code => resolve(code ?? 1));
  });
  assert.equal(exitCode, 0, 'Chrome real-SDK save probe must pass');
  const stored = (await db.doc(`users/${uid}/workouts/browser-lesson`).get()).data();
  assert.equal(stored.name, 'Browser restored lesson');
  assert.equal(stored.modules.length, 1);
  assert.equal((await db.doc(`users/${uid}/planUsage/current`).get()).data().workoutCount, 1);
  console.log('PASS: Chrome real Flutter repository/Auth/Storage/Functions/Firestore save and readback; emulator admin independently confirms restored content and usage');
} finally {
  await deleteApp(app);
}
