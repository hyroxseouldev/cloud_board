import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getDatabase} from 'firebase-admin/database';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
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
  async deleteDocuments(uid) { await db.recursiveDelete(db.doc(`users/${uid}`)); },
  async deleteRealtime(uid) { await userRef(uid).remove(); },
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
  catch(error) { throw new HttpsError(error.message==='reauthentication-required'?'failed-precondition':'unauthenticated','Google 계정으로 다시 본인 확인해 주세요.'); }
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
      await job.ref.delete();
    }
  }
});
