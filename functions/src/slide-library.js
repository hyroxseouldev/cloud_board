import {validateWorkoutTiming} from './workout-timing.js';
import {isDeepStrictEqual} from 'node:util';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';

export function favoriteLimit(entitlement) {
  if (entitlement?.plan === 'premium' && entitlement.favoritesUnlimited === true) return null;
  if (entitlement?.plan === 'legacy' && entitlement.maxFavorites == null) return null;
  return 3;
}

function validId(id) { return typeof id === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(id); }
function validateValue(value, id) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || value.id !== id ||
      typeof value.name !== 'string' || value.name.length > 200 ||
      (value.includeFinalRest !== undefined && typeof value.includeFinalRest !== 'boolean') ||
      typeof value.favorite !== 'boolean' || typeof value.category !== 'string' ||
      typeof value.text !== 'string' || typeof value.imageUrl !== 'string' ||
      (value.imageUrl !== '' && !/^https?:\/\//.test(value.imageUrl)) ||
      !['workSeconds', 'restSeconds', 'sets'].every(key => Number.isSafeInteger(value[key]) && value[key] >= 0) ||
      !['showTimer', 'beep', 'coverImage'].every(key => typeof value[key] === 'boolean') ||
      !value.appearance || typeof value.appearance !== 'object' ||
      !Array.isArray(value.intervalBlocks) ||
      (value.timingVersion !== undefined && (!Number.isSafeInteger(value.timingVersion) || ![1, 2, 3].includes(value.timingVersion))) ||
      ((value.timingVersion >= 2 || value.timerMode !== undefined || value.timerDirection !== undefined || (value.rounds ?? 1) !== 1 || (value.roundRestSeconds ?? 0) !== 0) && !validateWorkoutTiming(value)) ||
      Buffer.byteLength(JSON.stringify(value)) > 200000) {
    throw new HttpsError('invalid-argument', '슬라이드 데이터 형식을 확인해 주세요.');
  }
}

// Compare serialized DTO defaults consistently with old stored documents.
// New optional fields must not make every legacy edit look like a conflict.
export function normalizeLibraryValue(value) {
  if (!value) return null;
  return {showTimerGauge: true, favorite: false, category: '', timerColorValue: null,
    workGaugeColor: null, restGaugeColor: null, workTextColor: null, restTextColor: null,
    intervalBlocks: [], includeFinalRest: true, timingVersion: 1, rounds: 1,
    roundRestSeconds: 0, includeFinalRoundRest: true, timerMode: 'custom', timerDirection: 'down', ...value,
    designLayout: value.designLayout ?? 'auto',
    designFontWeight: value.designFontWeight ?? 900,
    designItalic: value.designItalic ?? true,
    designSpacing: value.designSpacing ?? 1.0,
    showSets: value.showSets ?? value.showTimer,
    appearance: {timerX: .84, timerY: .5, timerSize: 1, ringWidth: 30, setsSize: 1, setsOffsetY: .07,
      showTitle: true, showBody: true, showBrand: true, titleColor: 0xFFFFFFFF, bodyColor: 0xFFFFFFFF,
      setsColor: 0xB3FFFFFF, brandColor: 0xFFFFFFFF, ...value.appearance},
  };
}

// Item patches avoid overwriting unrelated changes from another controller.
// The shared counter serializes saved-slide quota across concurrent device requests.
export async function mutateSlideLibrary(db, uid, data) {
  if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
  if (data?.ownerId !== uid) throw new HttpsError('permission-denied', '로그인 계정이 변경되었습니다.');
  const {kind, changes, migration = false} = data ?? {};
  if (!['templates', 'styles'].includes(kind) || typeof migration !== 'boolean' ||
      !Array.isArray(changes) || changes.length < 1 || changes.length > 50 ||
      new Set(changes.map(c => c?.id)).size !== changes.length) {
    throw new HttpsError('invalid-argument', '잘못된 라이브러리 요청입니다.');
  }
  for (const change of changes) {
    if (!change || !validId(change.id) || !Object.hasOwn(change, 'value') || !Object.hasOwn(change, 'base')) {
      throw new HttpsError('invalid-argument', '잘못된 슬라이드 ID입니다.');
    }
    if (change.value !== null) validateValue(change.value, change.id);
    if (change.base !== null) validateValue(change.base, change.id);
    if (migration && (change.base !== null || change.value === null)) throw new HttpsError('invalid-argument', '잘못된 이전 요청입니다.');
  }
  const collection = db.collection(`users/${uid}/slide${kind === 'templates' ? 'Templates' : 'Styles'}`);
  const index = db.doc(`users/${uid}/libraryState/index`);
  return db.runTransaction(async tx => {
    const refs = changes.map(c => collection.doc(c.id));
    const [lock, entitlement, count, ...snapshots] = await tx.getAll(
      db.doc(`accountDeletions/${uid}`), db.doc(`subscriptionEntitlements/${uid}`), index, ...refs);
    if (lock.exists) throw new HttpsError('permission-denied', '탈퇴 처리 중인 계정입니다.');
    const limit = favoriteLimit(entitlement.data());
    let favorites = count.data()?.favoriteCount ?? 0;
    // Saved slides are the bookmark library. Keep legacy records and flags
    // intact; initialize the new count once under the shared transaction lock.
    let saved = count.data()?.savedCount;
    if (kind === 'templates' && !Number.isSafeInteger(saved)) {
      saved = (await tx.get(collection)).docs.filter(doc => !doc.data().deleted && doc.data().value).length;
    }
    let demoted = 0;
    const writes = [];
    for (let i = 0; i < changes.length; i++) {
      const change = changes[i], stored = snapshots[i].data();
      // Tombstones deliberately survive: another device's legacy cache must not
      // resurrect a deleted template when that device upgrades later.
      if (migration && snapshots[i].exists) continue;
      const current = stored?.deleted ? null : stored?.value ?? null;
      let next = change.value;
      if (isDeepStrictEqual(normalizeLibraryValue(current), normalizeLibraryValue(next))) continue; // Retry after lost response.
      if (!migration && (!isDeepStrictEqual(normalizeLibraryValue(current), normalizeLibraryValue(change.base)) || (stored?.deleted && change.base === null))) {
        throw new HttpsError('aborted', '다른 기기에서 변경한 항목입니다. 새로 불러온 뒤 다시 시도해 주세요.');
      }
      if (kind === 'templates') {
        if (!migration && next !== null && current === null && limit !== null && saved >= limit) {
          throw new HttpsError('resource-exhausted', '플러스는 슬라이드를 3개까지 저장할 수 있어요. 기존 자료는 유지됩니다.');
        }
        saved += Number(next !== null) - Number(current !== null);
        favorites += Number(next?.favorite === true) - Number(current?.favorite === true);
      }
      writes.push([refs[i], {schemaVersion: 1, deleted: next === null, value: next,
        updatedAt: FieldValue.serverTimestamp()}]);
    }
    for (const [ref, value] of writes) tx.set(ref, value);
    if (writes.length) tx.set(index, {favoriteCount: favorites, ...(kind === 'templates' ? {savedCount: saved} : {}), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    return {changed: writes.length, demoted};
  });
}

// Compatibility entry point retained for existing entitlement triggers.
export async function reconcileSlideLibraryFavorites(db, uid) {
  // Plan changes never demote or delete saved content. New saves enforce quota.
  return 0;
}
