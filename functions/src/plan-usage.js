import {FieldValue} from 'firebase-admin/firestore';
import {planPolicyVersion} from './plan-policy.js';

export const planUsageRef = (db, uid) => db.doc(`users/${uid}/planUsage/current`);

// Projection-only reads avoid downloading exercise/image payloads. Recounting
// inside the transaction handles legacy direct deletes immediately, including a
// delete whose asynchronous projection has not run yet. All new v2 creates also
// read/write the shared usage document, serializing competing final-slot saves.
export async function readPlanUsage(tx, db, uid) {
  const [workouts, slides] = await Promise.all([
    tx.get(db.collection(`users/${uid}/workouts`).select()),
    tx.get(db.collection(`users/${uid}/slideTemplates`).select('deleted', 'value.id', 'value.favorite')),
  ]);
  const active = slides.docs.filter(doc => doc.data().deleted !== true && doc.data().value);
  return {workoutCount: workouts.size, savedSlideCount: active.length,
    favoriteCount: active.filter(doc => doc.data().value.favorite === true).length};
}

export function writePlanUsage(tx, db, uid, counts) {
  tx.set(planUsageRef(db, uid), {policyVersion: planPolicyVersion,
    workoutCount: counts.workoutCount, savedSlideCount: counts.savedSlideCount,
    updatedAt: FieldValue.serverTimestamp()});
}

// Read current documents, not the event body: duplicate/out-of-order trigger
// delivery cannot resurrect a deleted item or regress usage after a new save.
export async function reconcilePlanUsage(db, uid) {
  return db.runTransaction(async tx => {
    const [lock] = await tx.getAll(db.doc(`accountDeletions/${uid}`), planUsageRef(db, uid));
    if (lock.exists) return null;
    const counts = await readPlanUsage(tx, db, uid);
    writePlanUsage(tx, db, uid, counts);
    return counts;
  });
}

// Workout content never changes cardinality. Keep recounting creates/deletes
// (including old clients' direct deletes), and conservatively handle events
// whose before/after snapshots are unavailable.
export async function reconcileWorkoutPlanUsage(db, uid, change) {
  if (change?.before?.exists === true && change?.after?.exists === true) return null;
  return reconcilePlanUsage(db, uid);
}
