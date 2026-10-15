import {isDeepStrictEqual} from 'node:util';
import {Timestamp} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {assertPlanCapacity} from './plan-policy.js';
import {planUsageRef, readPlanUsage, writePlanUsage} from './plan-usage.js';
import {summarizeWorkout} from './workout-catalog.js';
import {legacySettingKeys} from './workout-settings-migration.js';

const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const conflict = () => new HttpsError('aborted', '다른 기기에서 변경한 수업입니다. 편집 내용을 유지한 채 다시 확인해 주세요.', {reason: 'workout-revision-conflict'});
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

// The client prepares WorkoutSaveDocuments from its server snapshot so its
// versioned DTO preserves unknown fields. Compare that exact snapshot revision
// again here before committing; a stale prepared document can never win.
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
  const value = {...documentValue(source), createdAt: Timestamp.fromMillis(source.createdAt), updatedAt: Timestamp.fromMillis(source.updatedAt)};
  return db.runTransaction(async tx => {
    const ref = db.doc(`users/${uid}/workouts/${source.id}`);
    const [lock, entitlement, previous, settings] = await tx.getAll(
      db.doc(`accountDeletions/${uid}`), db.doc(`subscriptionEntitlements/${uid}`),
      ref, db.doc(`users/${uid}/settings/workout`), planUsageRef(db, uid));
    if (lock.exists) throw new HttpsError('permission-denied', '탈퇴 처리 중인 계정입니다.');
    const current = previous.data();
    if ((ifAbsent && previous.exists) || (current && isDeepStrictEqual(workoutWire(current), source))) {
      return {workout: workoutWire(current), created: false};
    }
    if ((requireExisting && !previous.exists) ||
        (previous.exists && expectedUpdatedAt !== null && millis(current.updatedAt) !== expectedUpdatedAt) ||
        (previous.exists && expectedUpdatedAt === null) ||
        (previous.exists && millis(current.createdAt) !== source.createdAt)) throw conflict();
    if ((settings.data()?.contentOnly === true) !== settingsContentOnly) throw conflict();
    if (settingsContentOnly) {
      if (value.schemaVersion !== 2 || legacySettingKeys.some(key => Object.hasOwn(value, key))) {
        throw new HttpsError('invalid-argument', '수업 설정 버전을 확인해 주세요.');
      }
    } else {
      delete value.schemaVersion;
      if (current) for (const key of legacySettingKeys) {
        if (Object.hasOwn(current, key)) value[key] = current[key];
        else delete value[key];
      }
    }
    const counts = await readPlanUsage(tx, db, uid);
    if (!previous.exists) assertPlanCapacity(entitlement.data(), 'workouts', counts.workoutCount);
    const summary = summarizeWorkout(value, value.id);
    tx.set(ref, value);
    tx.set(db.doc(`users/${uid}/workoutSummaries/${source.id}`), summary);
    writePlanUsage(tx, db, uid, {...counts, workoutCount: counts.workoutCount + Number(!previous.exists)});
    return {workout: workoutWire(value), created: !previous.exists};
  });
}
