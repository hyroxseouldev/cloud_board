import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
const require = createRequire(new URL('../../functions/package.json', import.meta.url));
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');
const {getDatabase} = require('firebase-admin/database');

// This script deliberately refuses to operate on a production endpoint/project.
const projectId = 'demo-cloudboard-studio';
for (const [key, port] of Object.entries({
  FIREBASE_AUTH_EMULATOR_HOST: 9099,
  FIRESTORE_EMULATOR_HOST: 8080,
  FIREBASE_DATABASE_EMULATOR_HOST: 9000,
})) {
  const endpoint = process.env[key] ?? `127.0.0.1:${port}`;
  assert.match(endpoint, /^(127\.0\.0\.1|localhost):\d+$/);
  process.env[key] = endpoint;
}
const app = initializeApp({projectId, databaseURL:
  `https://${projectId}-default-rtdb.asia-southeast1.firebasedatabase.app`});
const uid = 'studio-preview', storeId = 'studio-preview-center';
const auth = getAuth(app), db = getFirestore(app), realtime = getDatabase(app);
try {
  const account = {email: 'studio-preview@example.test', password: 'local-preview-only',
    displayName: '디자인 미리보기', emailVerified: true};
  try { await auth.createUser({uid, ...account}); }
  catch (error) {
    if (error.code !== 'auth/uid-already-exists' && error.code !== 'auth/email-already-exists') throw error;
    await auth.updateUser(uid, account);
  }
  const now = Timestamp.now(), expiry = Date.now() + 30 * 86400000;
  const batch = db.batch();
  batch.set(db.doc(`users/${uid}`), {uid, email: account.email, displayName: account.displayName,
    updatedAt: now}, {merge: true});
  batch.set(db.doc(`subscriptionEntitlements/${uid}`), {plan: 'premium', status: 'active',
    validUntilMs: expiry, managed: true, displayLimit: 3});
  batch.set(db.doc(`centers/${storeId}`), {ownerUid: uid, revision: 1,
    profile: {centerName: 'PREVIEW STUDIO', centerTypes: ['functional'], classTypes: ['group'],
      purpose: 'operating', role: 'owner', province: '서울', district: '강남구'},
    createdAt: now, updatedAt: now});
  batch.set(db.doc(`users/${uid}/onboarding/progress`), {storeId, completed: true,
    deferred: false, phoneVerified: true, step: 3, updatedAt: now});
  await batch.commit();
  const cases = JSON.parse(await readFile(new URL('../../test/fixtures/slide_design_reference_cases.json', import.meta.url), 'utf8'));
  const accents = [0xFFEB792D, 0xFF244566, 0xFF43C413, 0xFF299FDC, 0xFFE13A43, 0xFFE13A43, 0xFFD91F50];
  const modules = cases.map((item, index) => {
    const poster = item.id === 'dolpa-brick';
    return {id: item.id, name: item.header, text: item.rows.join('\n'), imageUrl: '',
      workSeconds: 60, sets: 1, restSeconds: 0, timingVersion: 2,
      showTimer: false, showSets: false, beep: false, coverImage: false,
      designTemplate: poster ? 'studio-v1-list' : 'studio-v1-numbered',
      designStyle: {version: 1, family: poster ? 'editorial' : 'banner',
        fontFamily: poster ? 'serif' : 'sans', titleColor: poster ? accents[index] : 0xFFFFFFFF,
        titleWeight: poster ? 700 : 900, motif: poster ? '突破' : ''},
      designHeaderLabel: poster ? '' : item.programLabel, designSubtitle: item.timingText,
      designBackgroundColor: poster ? 0xFF000000 : 0xFFFFFFFF,
      designTextColor: poster ? 0xFFFFFFFF : 0xFF151515, designAccentColor: accents[index],
      designFontWeight: poster ? 400 : 700, designItalic: false,
      appearance: {showTitle: false, showBody: false, showBrand: false}};
  });
  const workoutId = 'studio-reference-review';
  const workoutRef = db.doc(`users/${uid}/workouts/${workoutId}`);
  if (!(await workoutRef.get()).exists) {
    await workoutRef.set({id: workoutId, ownerId: uid,
      author: {id: uid, displayName: account.displayName, photoUrl: null},
      name: '참고 수업 7종 · 디자인 검수', folder: '', brandL: 'PREVIEW STUDIO', brandR: '',
      modules, createdAt: now, updatedAt: now});
  }
  await realtime.ref(`users/${uid}/operations/brand`).set({storeName: 'PREVIEW STUDIO',
    logoUrl: '', primaryColorValue: 0xFF3657D6, promoImages: []});
  await realtime.ref(`subscriptionAccess/${uid}`).set({plan: 'premium', status: 'active',
    validUntilMs: expiry, displayLimit: 3});
  console.log('Seeded local preview center and premium fixture; production untouched.');
} finally { await deleteApp(app); }
