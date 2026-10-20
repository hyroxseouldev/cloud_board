import {isDeepStrictEqual} from 'node:util';
import {Timestamp} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {assertPlanCapacity} from './plan-policy.js';
import {planUsageRef, readPlanUsage, writePlanUsage} from './plan-usage.js';
import {summarizeWorkout} from './workout-catalog.js';
import {legacySettingKeys, legacyWorkoutSettings} from './workout-settings-migration.js';

const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const millis = value => typeof value?.toMillis === 'function' ? value.toMillis() : value;
const wireValue = value => value instanceof Timestamp ? {__timestampMillis:value.toMillis()} :
  Array.isArray(value) ? value.map(wireValue) : value && typeof value === 'object' ?
    Object.fromEntries(Object.entries(value).map(([key,item])=>[key,wireValue(item)])) : value;
const documentValue = value => value && typeof value === 'object' && Object.keys(value).length === 1 &&
    Number.isSafeInteger(value.__timestampMillis) ? Timestamp.fromMillis(value.__timestampMillis) :
  Array.isArray(value) ? value.map(documentValue) : value && typeof value === 'object' ?
    Object.fromEntries(Object.entries(value).map(([key,item])=>[key,documentValue(item)])) : value;
export function workoutWire(value) {
  return {...wireValue(value), createdAt: millis(value.createdAt), updatedAt: millis(value.updatedAt)};
}

// Saves by the owner use last-write-wins content. Revision fields remain valid
// inputs for installed clients, but do not prevent a deliberate save or restore.
// The client's versioned DTO owns content and unknown-field preservation. Read
// the latest document in the transaction only to retain its creation time and
// settings compatibility values, without resurrecting deliberately removed data.
export async function saveWorkout(db, uid, input) {
  if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
  if (input?.ownerId !== uid) throw new HttpsError('permission-denied', '로그인 계정이 변경되었습니다.');
  const {workout: source, ifAbsent = false, requireExisting = false,
    expectedUpdatedAt = null, settingsContentOnly = false} = input;
  if (!source || !validId(source.id) || source.ownerId !== uid || source.author?.id !== uid ||
      typeof source.name !== 'string' || typeof source.folder !== 'string' ||
      !Array.isArray(source.modules) || !Number.isSafeInteger(source.createdAt) ||
      !Number.isSafeInteger(source.updatedAt) || source.createdAt < 0 || source.updatedAt < 0 ||
      source.createdAt > 253402300799999 || source.updatedAt > 253402300799999 ||
      ![ifAbsent, requireExisting, settingsContentOnly].every(v => typeof v === 'boolean') ||
      (expectedUpdatedAt !== null && !Number.isSafeInteger(expectedUpdatedAt)) ||
      Buffer.byteLength(JSON.stringify(source)) > 900000) {
    throw new HttpsError('invalid-argument', '수업 데이터 형식을 확인해 주세요.');
  }
  return db.runTransaction(async tx => {
    const ref = db.doc(`users/${uid}/workouts/${source.id}`);
    const [lock, entitlement, previous, settings] = await tx.getAll(
      db.doc(`accountDeletions/${uid}`), db.doc(`subscriptionEntitlements/${uid}`),
      ref, db.doc(`users/${uid}/settings/workout`));
    if (lock.exists) throw new HttpsError('permission-denied', '탈퇴 처리 중인 계정입니다.');
    const current = previous.data();
    if (ifAbsent && previous.exists) {
      return {workout: workoutWire(current), created: false};
    }
    const value = {...documentValue(source),
      createdAt: current?.createdAt ?? Timestamp.fromMillis(source.createdAt),
      updatedAt: Timestamp.fromMillis(source.updatedAt)};
    const canonical = settings.data();
    if (canonical?.contentOnly === true) {
      value.schemaVersion = 2;
      for (const key of legacySettingKeys) delete value[key];
    } else {
      delete value.schemaVersion;
      let legacy = current?.schemaVersion !== 2 ? current : null;
      if (!legacy && (source.schemaVersion === 2 || settingsContentOnly || current?.schemaVersion === 2)) {
        if (!canonical?.preferences) {
          throw new HttpsError('failed-precondition', '수업 설정을 확인할 수 없습니다. 잠시 후 다시 저장해 주세요.');
        }
        try { legacy = legacyWorkoutSettings(canonical.preferences); }
        catch { throw new HttpsError('failed-precondition', '수업 설정을 확인할 수 없습니다. 잠시 후 다시 저장해 주세요.'); }
      }
      if (legacy) for (const key of legacySettingKeys) {
        if (Object.hasOwn(legacy, key)) value[key] = legacy[key];
        else delete value[key];
      }
    }
    if (current && isDeepStrictEqual(current, value)) {
      return {workout: workoutWire(current), created: false};
    }
    let counts;
    if (!previous.exists) {
      // Creates/restores still serialize on usage and recount actual documents,
      // including legacy direct deletes whose trigger has not run yet. An edit
      // reads its workout in this transaction; a concurrent delete retries here
      // as a create, so skipping usage for edits cannot bypass the final slot.
      await tx.get(planUsageRef(db, uid));
      counts = await readPlanUsage(tx, db, uid);
      assertPlanCapacity(entitlement.data(), 'workouts', counts.workoutCount);
    }
    const summary = summarizeWorkout(value, value.id);
    tx.set(ref, value);
    tx.set(db.doc(`users/${uid}/workoutSummaries/${source.id}`), summary);
    if (counts) writePlanUsage(tx, db, uid, {...counts, workoutCount: counts.workoutCount + 1});
    return {workout: workoutWire(value), created: !previous.exists};
  });
}
