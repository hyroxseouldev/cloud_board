import assert from 'node:assert/strict';
import {getAuth} from 'firebase-admin/auth';
import {getDatabase} from 'firebase-admin/database';
import {getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';

// Only these dedicated identities may be provisioned, inspected or cleaned up.
export const canaryUsers = Object.freeze({owner: 'cloudboard-release-owner', other: 'cloudboard-release-other', tv: 'cloudboard-release-tv'});
export function checkRunId(runId) { assert.match(runId || '', /^\d{1,20}-\d{1,4}$/); return `release-${runId}`; }
export async function prepareCanary(app, runId) {
  const id = checkRunId(runId), auth = getAuth(app), db = getDatabase(app);
  for (const uid of Object.values(canaryUsers)) {
    let user;
    try { user = await auth.getUser(uid); }
    catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      await auth.createUser({uid, displayName: 'CloudBoard release check'});
      await auth.setCustomUserClaims(uid, {cloudboardReleaseCanary: true});
      user = await auth.getUser(uid);
    }
    assert.equal(user.customClaims?.cloudboardReleaseCanary, true, 'Reserved canary UID is not provisioned as a canary');
    assert.equal(user.disabled, false);
  }
  const lease = await db.ref('releaseCanaryLease').transaction(current => {
    // Expiry is diagnostic only. A killed run may have left fixture data behind;
    // require its scoped cleanup before another run can acquire the namespace.
    if (current && current.runId !== runId) return;
    return {runId, expiresAtMs: Date.now() + 10 * 60_000};
  });
  assert(lease.committed, 'Another or unfinished canary run owns the lease');
  const owner = canaryUsers.owner;
  await db.ref().update({
    [`subscriptionAccess/${owner}`]: {plan: 'plus', managed: true, validUntilMs: Date.now() + 10 * 60_000, canaryRun: runId},
    [`displayAccess/${canaryUsers.tv}`]: {ownerId: owner, deviceId: id, pairingCode: '000000', canaryRun: runId},
    [`users/${owner}/devices/${id}`]: {id, mode: 'display', displayUid: canaryUsers.tv, paired: true, displayState: 'auto', online: true, lastSeenAtMs: Date.now()},
  });
  // Tokens are passed in memory to the client SDK, never serialized to evidence.
  return Object.fromEntries(await Promise.all(Object.entries(canaryUsers).map(async ([role, uid]) => [role, await auth.createCustomToken(uid)])));
}
export async function cleanupCanary(app, runId) {
  const id = checkRunId(runId), owner = canaryUsers.owner, db = getDatabase(app);
  const leaseRef = db.ref('releaseCanaryLease'), lease = (await leaseRef.get()).val();
  if (lease?.runId !== runId) return; // Never clean another run's state.
  for (const uid of Object.values(canaryUsers)) {
    assert.equal((await getAuth(app).getUser(uid)).customClaims?.cloudboardReleaseCanary, true);
  }
  await db.ref(`users/${owner}/activeSession`).transaction(value => value == null || value.id === id ? null : undefined);
  await db.ref().update({[`users/${owner}/playbackSnapshots/${id}`]: null, [`users/${owner}/devices/${id}`]: null});
  await db.ref(`displayAccess/${canaryUsers.tv}`).transaction(value => value == null || value.canaryRun === runId ? null : undefined);
  await db.ref(`subscriptionAccess/${owner}`).transaction(value => value == null || value.canaryRun === runId ? null : undefined);
  const firestore = getFirestore(app), batch = firestore.batch();
  batch.delete(firestore.doc(`users/${owner}/workouts/${id}`));
  batch.delete(firestore.doc(`users/${owner}/workoutSummaries/${id}`));
  await batch.commit();
  await getStorage(app).bucket().file(`users/${owner}/workouts/${id}/probe.png`).delete({ignoreNotFound: true});
  await leaseRef.transaction(value => value == null || value.runId === runId ? null : undefined);
}
