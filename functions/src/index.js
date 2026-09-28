import {prunePlaybackSnapshots} from './playback-snapshots.js';
import {onDocumentWritten, onDocumentCreated} from 'firebase-functions/v2/firestore';
import {syncWorkoutSummary, backfillCatalog} from './workout-catalog.js';
import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getDatabase} from 'firebase-admin/database';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {onCall, onRequest, HttpsError} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {onMessagePublished} from 'firebase-functions/v2/pubsub';
import {eraseAccount, requireDeletionIdentity} from './delete-account.js';

const projectId=process.env.GCLOUD_PROJECT || 'cloud-board-stationd';
initializeApp({projectId,databaseURL:`https://${projectId}-default-rtdb.asia-southeast1.firebasedatabase.app`,storageBucket:`${projectId}.firebasestorage.app`});
const db=getFirestore(), realtime=getDatabase(), auth=getAuth(), bucket=getStorage().bucket();
const jobs=db.collection('accountDeletions');
const region='asia-northeast3';
const userRef=uid=>realtime.ref(`users/${uid}`);
async function ignoreMissingAuth(action) {
  try { await action(); } catch(error) { if(error.code!=='auth/user-not-found') throw error; }
}
const services={
  async lock(uid) {
    await jobs.doc(uid).set({status:'processing',updatedAt:Timestamp.now()}, {merge:true});
    await realtime.ref(`accountDeletions/${uid}`).set(true);
  },
  async stopAndDetach(uid) {
    const session=userRef(uid).child('activeSession');
    const value=(await session.get()).val();
    if(value) await session.update({status:'completed',remainingMs:0,briefing:false,revision:(value.revision||0)+1,anchorServerMs:Date.now()});
    // Query global references by owner, not by an untrusted client-provided list.
    for(const name of ['displayAccess','pairingCodes']) {
      const matches=await realtime.ref(name).orderByChild('ownerId').equalTo(uid).get();
      // Compare inside the transaction: never remove a mapping that another
      // owner acquired between the query and this cleanup.
      for(const key of Object.keys(matches.val()||{})) {
        await realtime.ref(`${name}/${key}`).transaction(current=>
          current===null || current.ownerId===uid ? null : undefined);
      }
    }
  },
  async disableAuth(uid) {
    await ignoreMissingAuth(()=>auth.updateUser(uid,{disabled:true}));
    await ignoreMissingAuth(()=>auth.revokeRefreshTokens(uid));
  },
  async deleteFiles(uid) { await bucket.deleteFiles({prefix:`users/${uid}/`}); },
  async deleteDocuments(uid) {
    const {deleteBillingData}=await import('./billing.js');
    await deleteBillingData(db,uid);
    const {deleteOnboardingData}=await import('./onboarding.js');
    await deleteOnboardingData(db,uid);
    await db.recursiveDelete(db.doc(`users/${uid}`));
  },
  async deleteRealtime(uid) {
    await userRef(uid).remove();
    await realtime.ref(`subscriptionAccess/${uid}`).remove();
  },
  async verifyEmpty(uid) {
    const [files, user, live, access, codes]=await Promise.all([
      bucket.getFiles({prefix:`users/${uid}/`,maxResults:1,autoPaginate:false}),
      db.doc(`users/${uid}`).get(), userRef(uid).get(),
      realtime.ref('displayAccess').orderByChild('ownerId').equalTo(uid).get(),
      realtime.ref('pairingCodes').orderByChild('ownerId').equalTo(uid).get(),
    ]);
    if(files[0].length||user.exists||live.exists()||access.exists()||codes.exists()) throw new Error('cleanup-incomplete');
    const collections=await db.doc(`users/${uid}`).listCollections();
    for(const collection of collections) if(!(await collection.limit(1).get()).empty) throw new Error('cleanup-incomplete');
  },
  async deleteAuth(uid) { await ignoreMissingAuth(()=>auth.deleteUser(uid)); },
  async complete(uid) {
    await jobs.doc(uid).set({status:'completed',completedAt:Timestamp.now(),updatedAt:Timestamp.now(),leaseUntil:Timestamp.fromMillis(0)}, {merge:true});
  },
};

async function processJob(uid) {
  const claimed=await db.runTransaction(async transaction=>{
    const ref=jobs.doc(uid), snap=await transaction.get(ref), data=snap.data();
    if(!data || data.status==='completed') return false;
    if(data.leaseUntil?.toMillis()>Date.now()) return false;
    transaction.update(ref,{leaseUntil:Timestamp.fromMillis(Date.now()+600000),attempts:(data.attempts||0)+1});
    return true;
  });
  if(!claimed) return (await jobs.doc(uid).get()).data()?.status==='completed';
  try { await eraseAccount(uid, services); return true; }
  catch(error) {
    if (process.env.FIREBASE_AUTH_EMULATOR_HOST) console.error('EMULATOR deletion failure:', error);
    // No email/name/content is written to logs. Retry safely from the lock step.
    await jobs.doc(uid).set({status:'pending',updatedAt:Timestamp.now(),leaseUntil:Timestamp.fromMillis(0)}, {merge:true});
    return false;
  }
}

export const deleteMyAccount=onCall({region,timeoutSeconds:540,memory:'512MiB',maxInstances:3},async request=>{
  let uid;
  try { uid=requireDeletionIdentity(request.auth,Date.now()/1000); }
  catch(error) { throw new HttpsError(error.message==='reauthentication-required'?'failed-precondition':'unauthenticated','로그인 계정으로 다시 본인 확인해 주세요.'); }
  if(request.data?.confirm!==true) throw new HttpsError('invalid-argument','삭제 확인이 필요합니다.');
  // Verify revocation/disabled status before creating a new destructive job.
  const existing=await jobs.doc(uid).get();
  if(!existing.exists) {
    const bearer=request.rawRequest.headers.authorization?.replace(/^Bearer /i,'');
    try { const verified=await auth.verifyIdToken(bearer||'',true); if(verified.uid!==uid) throw new Error('identity-mismatch'); }
    catch { throw new HttpsError('unauthenticated','다시 로그인해 주세요.'); }
    await db.runTransaction(async tx=>{
      const ref=jobs.doc(uid);
      if(!(await tx.get(ref)).exists) tx.create(ref,{status:'pending',requestedAt:Timestamp.now(),updatedAt:Timestamp.now(),attempts:0});
    });
  }
  const completed=await processJob(uid);
  return {status:completed?'completed':'processing'};
});

// Recover partial failures after the client closes or loses its connection.
export const retryAccountDeletions=onSchedule({region,schedule:'every 15 minutes',timeoutSeconds:540,memory:'512MiB',maxInstances:1},async()=>{
  const pending=await jobs.where('status','in',['pending','processing']).orderBy('updatedAt').limit(10).get();
  for(const job of pending.docs) await processJob(job.id);
  // Processing records follow the published 30-day retention. Locks also prevent
  // still-valid pre-deletion tokens from recreating content during their lifetime.
  const completed=await jobs.where('status','==','completed').where('completedAt','<',Timestamp.fromMillis(Date.now()-30*86400000)).limit(100).get();
  for(const job of completed.docs) {
    if(job.data().completedAt.toMillis()<Date.now()-30*86400000) {
      await realtime.ref(`accountDeletions/${job.id}`).remove();
      const billing = db.doc(`billingAccounts/${job.id}`);
      if ((await billing.get()).data()?.deleted === true) await billing.delete();
      await job.ref.delete();
    }
  }
});

// Compatibility bridge for old installed apps that only write workout details.
// New apps batch-write both documents; matching projections are a no-op here.
export const syncWorkoutCatalog = onDocumentWritten(
  {document: 'users/{uid}/workouts/{workoutId}', region, retry: true, maxInstances: 3},
  async event => {
    const {uid, workoutId} = event.params;
    await syncWorkoutSummary(db, uid, workoutId);
    if (!(await db.doc(`users/${uid}/catalog/schema`).get()).exists) {
      await backfillCatalog(db, uid);
    }
  },
);

// Bound immutable session storage. The active snapshot is always retained;
// recently ended snapshots allow slow/reconnecting clients to finish loading.
export const cleanupPlaybackSnapshots = onSchedule(
  {region, schedule: 'every 24 hours', timeoutSeconds: 540, maxInstances: 1},
  async () => {
    const cutoff = Date.now() - 7 * 86400000;
    let cursor;
    do {
      let query = db.collection('users').orderBy('__name__').limit(100);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const user of page.docs) {
        await prunePlaybackSnapshots(userRef(user.id), cutoff);
      }
      cursor = page.docs.at(-1);
      if (page.size < 100) break;
    } while (cursor);
  },
);

export const updateSlideLibrary = onCall({region, timeoutSeconds: 60, maxInstances: 10}, async request => {
  const {mutateSlideLibrary} = await import('./slide-library.js');
  return mutateSlideLibrary(db, request.auth?.uid, request.data);
});

export const syncSlideLibraryPlan = onDocumentWritten({
  region, document: 'subscriptionEntitlements/{uid}', retry: true,
  timeoutSeconds: 120, maxInstances: 5,
}, async event => {
  const {reconcileSlideLibraryFavorites} = await import('./slide-library.js');
  await reconcileSlideLibraryFavorites(db, event.params.uid);
});

// Firebase-native app onboarding. No web login or Postgres connection required.
export const cloudboardAppOnboarding = onCall({
  region, timeoutSeconds: 60, maxInstances: 3,
  secrets: ['CLOUDBOARD_ONBOARDING_SECRET', 'SOLAPI_API_KEY', 'SOLAPI_API_SECRET'],
}, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
  const bearer=request.rawRequest.headers.authorization?.replace(/^Bearer /i,'');
  try {
    const token=await auth.verifyIdToken(bearer||'',true);
    if(token.uid!==request.auth.uid) throw new Error();
  } catch { throw new HttpsError('unauthenticated','다시 로그인해 주세요.'); }
  const {handleOnboarding}=await import('./onboarding.js');
  const {sendOnboardingSms}=await import('./onboarding-sms.js');
  return handleOnboarding({db,realtime,auth:request.auth,input:request.data,
    secret:process.env.CLOUDBOARD_ONBOARDING_SECRET,send:sendOnboardingSms});
});

// Retrying projection repairs a dropped connection between the two Firebase stores.
export const syncAppTrialAccess = onDocumentWritten({
  region, document: 'subscriptionEntitlements/{uid}', retry: true, maxInstances: 3,
}, async event => {
  const {syncNativeTrial}=await import('./onboarding.js');
  await syncNativeTrial(db,realtime,event.params.uid);
  const {refreshEntitlements}=await import('./billing.js');
  if ((await db.doc(`billingAccounts/${event.params.uid}`).get()).exists) {
    await refreshEntitlements(db,realtime,event.params.uid);
  }
});

const appleSecrets = ['APPLE_IAP_PRIVATE_KEY', 'APPLE_IAP_KEY_ID', 'APPLE_IAP_ISSUER_ID'];
export const cloudboardBilling = onCall({region, secrets: appleSecrets, timeoutSeconds: 120, maxInstances: 5}, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
  const bearer = request.rawRequest.headers.authorization?.replace(/^Bearer /i, '');
  try {
    const token = await auth.verifyIdToken(bearer || '', true);
    if (token.uid !== request.auth.uid) throw new Error();
  } catch { throw new HttpsError('unauthenticated', '다시 로그인해 주세요.'); }
  const {handleBilling} = await import('./billing.js');
  return handleBilling(db, realtime, request.auth.uid, request.data);
});

export const appStoreNotifications = onRequest({region, timeoutSeconds: 60, maxInstances: 5}, async (request, response) => {
  if (request.method !== 'POST') { response.sendStatus(405); return; }
  const {acceptAppleNotification} = await import('./billing.js');
  try {
    await acceptAppleNotification(db, request.body?.signedPayload);
    response.sendStatus(200); // Acknowledge only after durable, verified enqueue.
  } catch (error) {
    const invalid = ['apple-signature-invalid', 'invalid-signed-payload', 'invalid-notification-id', 'environment-mismatch'].includes(error.message);
    response.sendStatus(invalid ? 400 : 503);
  }
});

export const processAppStoreNotification = onDocumentCreated({region,
  document: 'appStoreEvents/{eventId}', secrets: appleSecrets, retry: true,
  timeoutSeconds: 120, maxInstances: 5,
}, async event => {
  const {processAppleEvent} = await import('./billing.js');
  await processAppleEvent(db, realtime, event.data.ref);
});

export const reconcileAppStoreBilling = onSchedule({region, schedule: 'every 5 minutes',
  secrets: appleSecrets, timeoutSeconds: 540, maxInstances: 1,
}, async () => {
  const {refreshSubscription, refreshEntitlements, processAppleEvent} = await import('./billing.js');
  const now = Date.now();
  const events = await db.collection('appStoreEvents').where('nextAttemptAtMs', '<=', now).limit(50).get();
  for (const event of events.docs) await processAppleEvent(db, realtime, event.ref);
  const subscriptions = await db.collection('appStoreSubscriptions').where('nextCheckAtMs', '<=', now).limit(50).get();
  for (const sub of subscriptions.docs) {
    try { await refreshSubscription(db, realtime, sub.ref); }
    catch (_) { /* Keep the last VERIFIED expiry; never extend on network failure. */ }
  }
  const accounts = await db.collection('billingAccounts').where('nextCheckAtMs', '<=', now).limit(100).get();
  for (const account of accounts.docs) await refreshEntitlements(db, realtime, account.id);
  const finished = await db.collection('appStoreEvents').where('processedAtMs', '<', now - 30 * 86400000).limit(200).get();
  const batch = db.batch(); for (const event of finished.docs) batch.delete(event.ref); await batch.commit();
});

// Uses runtime Application Default Credentials. Grant this service account the
// app-scoped Play Console subscription permissions; never ship a JSON key.
export const cloudboardPlayBilling = onCall({region, timeoutSeconds: 120, maxInstances: 5}, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
  const bearer = request.rawRequest.headers.authorization?.replace(/^Bearer /i, '');
  try {
    if ((await auth.verifyIdToken(bearer || '', true)).uid !== request.auth.uid) throw new Error();
  } catch { throw new HttpsError('unauthenticated', '다시 로그인해 주세요.'); }
  const {handlePlayBilling} = await import('./google-play-billing.js');
  return handlePlayBilling(db, realtime, request.auth.uid, request.data);
});

export const googlePlayNotifications = onMessagePublished({region,
  topic: 'cloudboard-google-play', retry: true, timeoutSeconds: 60, maxInstances: 5,
}, async event => {
  let value;
  try { value = event.data.message.json; } catch { return; }
  const {acceptPlayNotification} = await import('./google-play-billing.js');
  await acceptPlayNotification(db, event.data.message.messageId, value);
});

export const processGooglePlayNotification = onDocumentCreated({region,
  document: 'googlePlayEvents/{eventId}', retry: true, timeoutSeconds: 120, maxInstances: 5,
}, async event => {
  const {processPlayEvent} = await import('./google-play-billing.js');
  await processPlayEvent(db, realtime, event.data.ref);
});

export const reconcileGooglePlayBilling = onSchedule({region, schedule: 'every 5 minutes',
  timeoutSeconds: 540, maxInstances: 1,
}, async () => {
  const {processPlayEvent, refreshPlaySubscription} = await import('./google-play-billing.js');
  const {refreshEntitlements} = await import('./billing.js');
  const now = Date.now();
  const events = await db.collection('googlePlayEvents').where('nextAttemptAtMs', '<=', now).limit(50).get();
  for (const event of events.docs) await processPlayEvent(db, realtime, event.ref);
  const subscriptions = await db.collection('googlePlaySubscriptions').where('nextCheckAtMs', '<=', now).limit(50).get();
  for (const sub of subscriptions.docs) {
    try { await refreshPlaySubscription(db, realtime, sub.ref); }
    catch (_) { /* Retain only the verified expiry on network/permission failure. */ }
  }
  const accounts = await db.collection('billingAccounts').where('nextCheckAtMs', '<=', now).limit(100).get();
  for (const account of accounts.docs) await refreshEntitlements(db, realtime, account.id);
  const finished = await db.collection('googlePlayEvents').where('processedAtMs', '<', now - 30 * 86400000).limit(200).get();
  const batch = db.batch(); for (const event of finished.docs) batch.delete(event.ref); await batch.commit();
});

export const cleanupOnboardingVerification = onSchedule({region,schedule:'every 24 hours',maxInstances:1},async()=>{
  for(const [collection,field,cutoff] of [
    ['onboardingPhoneChallenges','expiresAtMs',Date.now()-86400000],
    ['onboardingSmsLimits','expiresAt',Timestamp.now()],
  ]) {
    let page;
    do {
      page=await db.collection(collection).where(field,'<',cutoff).limit(400).get();
      const batch=db.batch(); for(const document of page.docs) batch.delete(document.ref); await batch.commit();
    } while(page.size===400);
  }
});
