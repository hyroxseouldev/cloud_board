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
      typeof value.favorite !== 'boolean' || typeof value.category !== 'string' ||
      typeof value.text !== 'string' || typeof value.imageUrl !== 'string' ||
      (value.imageUrl !== '' && !/^https?:\/\//.test(value.imageUrl)) ||
      !['workSeconds', 'restSeconds', 'sets'].every(key => Number.isSafeInteger(value[key]) && value[key] >= 0) ||
      !['showTimer', 'beep', 'coverImage'].every(key => typeof value[key] === 'boolean') ||
      !value.appearance || typeof value.appearance !== 'object' ||
      !Array.isArray(value.intervalBlocks) || Buffer.byteLength(JSON.stringify(value)) > 200000) {
    throw new HttpsError('invalid-argument', '슬라이드 데이터 형식을 확인해 주세요.');
  }
}

// Item patches avoid overwriting unrelated changes from another controller.
// The shared counter serializes favorites across concurrent device requests.
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
    let demoted = 0;
    const writes = [];
    for (let i = 0; i < changes.length; i++) {
      const change = changes[i], stored = snapshots[i].data();
      // Tombstones deliberately survive: another device's legacy cache must not
      // resurrect a deleted template when that device upgrades later.
      if (migration && snapshots[i].exists) continue;
      const current = stored?.deleted ? null : stored?.value ?? null;
      let next = change.value;
      if (isDeepStrictEqual(current, next)) continue; // Retry after lost response.
      if (!migration && (!isDeepStrictEqual(current, change.base) || (stored?.deleted && change.base === null))) {
        throw new HttpsError('aborted', '다른 기기에서 변경한 항목입니다. 새로 불러온 뒤 다시 시도해 주세요.');
      }
      if (kind === 'templates') {
        const adding = next?.favorite === true && current?.favorite !== true;
        if (adding && limit !== null && favorites >= limit) {
          if (!migration) throw new HttpsError('resource-exhausted', '플러스는 즐겨찾기를 3개까지 등록할 수 있어요. 기존 즐겨찾기를 해제하거나 프리미엄을 이용해 주세요.');
          next = {...next, favorite: false};
          demoted++;
        }
        favorites += Number(next?.favorite === true) - Number(current?.favorite === true);
      }
      writes.push([refs[i], {schemaVersion: 1, deleted: next === null, value: next,
        updatedAt: FieldValue.serverTimestamp()}]);
    }
    for (const [ref, value] of writes) tx.set(ref, value);
    if (writes.length) tx.set(index, {favoriteCount: favorites, updatedAt: FieldValue.serverTimestamp()});
    return {changed: writes.length, demoted};
  });
}

// A downgrade must also enforce the registration limit for existing favorites.
// Re-read the current entitlement: delayed/retried events must not undo a newer upgrade.
export async function reconcileSlideLibraryFavorites(db, uid) {
  let demoted = 0;
  for (;;) {
    const changed = await db.runTransaction(async tx => {
      const index = db.doc(`users/${uid}/libraryState/index`);
      const [lock, entitlement, counter] = await tx.getAll(
        db.doc(`accountDeletions/${uid}`), db.doc(`subscriptionEntitlements/${uid}`), index);
      const limit = favoriteLimit(entitlement.data());
      if (lock.exists || limit === null) return 0;
      const favorites = await tx.get(db.collection(`users/${uid}/slideTemplates`)
        .where('value.favorite', '==', true).limit(limit + 400).select('value.favorite'));
      const excess = favorites.docs.slice(limit);
      for (const item of excess) tx.update(item.ref, {'value.favorite': false, updatedAt: FieldValue.serverTimestamp()});
      if (excess.length) tx.set(index, {
        favoriteCount: Math.max(limit, (counter.data()?.favoriteCount ?? favorites.size) - excess.length),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return excess.length;
    });
    demoted += changed;
    if (changed < 400) return demoted;
  }
}
