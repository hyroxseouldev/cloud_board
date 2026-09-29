import {createHash} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {summarizeWorkout} from './workout-catalog.js';

export function folderName(value, {empty = false} = {}) {
  if (typeof value !== 'string' || value.trim().length > 40 || (!empty && !value.trim()) || /[\u0000-\u001f]/.test(value)) throw new HttpsError('invalid-argument', '폴더 이름은 1~40자로 입력해 주세요.');
  return value.trim();
}
export async function manageLibraryFolder(db, uid, data) {
  if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
  if (!['create', 'rename', 'remove'].includes(data?.action)) throw new HttpsError('invalid-argument', '잘못된 폴더 작업입니다.');
  const from = folderName(data.name);
  const to = data.action === 'rename' ? folderName(data.newName) : data.action === 'create' ? from : '';
  if (data.action === 'rename' && from === to) return {changed: 0};
  const root = `users/${uid}`;
  const doc = name => db.doc(`${root}/libraryFolders/${createHash('sha256').update(name).digest('hex')}`);
  return db.runTransaction(async tx => {
    const [lock, source, index, workouts, slides, destination] = await Promise.all([
      tx.get(db.doc(`accountDeletions/${uid}`)), tx.get(doc(from)), tx.get(db.doc(`${root}/libraryState/index`)),
      tx.get(db.collection(`${root}/workouts`).where('folder', '==', from)),
      tx.get(db.collection(`${root}/slideTemplates`).where('value.category', '==', from)),
      to ? tx.get(doc(to)) : Promise.resolve(null),
    ]);
    if (lock.exists) throw new HttpsError('permission-denied', '탈퇴 처리 중인 계정입니다.');
    if (data.action === 'create') {
      if (source.exists || !workouts.empty || !slides.empty) throw new HttpsError('already-exists', '이미 있는 폴더입니다.');
      tx.set(doc(to), {name: to, updatedAt: FieldValue.serverTimestamp()});
      return {changed: 1};
    }
    if (!source.exists && workouts.empty && slides.empty) throw new HttpsError('not-found', '폴더가 변경되었거나 삭제되었습니다.');
    if (to) {
      const [targetWorkouts, targetSlides] = await Promise.all([
        tx.get(db.collection(`${root}/workouts`).where('folder', '==', to).limit(1)),
        tx.get(db.collection(`${root}/slideTemplates`).where('value.category', '==', to).limit(1)),
      ]);
      if (destination.exists || !targetWorkouts.empty || !targetSlides.empty) throw new HttpsError('already-exists', '이미 있는 폴더입니다. 다른 이름을 입력해 주세요.');
    }
    if (workouts.size * 2 + slides.size > 440) throw new HttpsError('resource-exhausted', '한 번에 변경할 수 있는 항목 수를 초과했습니다. 일부 항목을 먼저 옮겨 주세요.');
    for (const item of workouts.docs) {
      const value = {...item.data(), folder: to, updatedAt: FieldValue.serverTimestamp()};
      tx.update(item.ref, {folder: to, updatedAt: value.updatedAt});
      tx.set(db.doc(`${root}/workoutSummaries/${item.id}`), summarizeWorkout(value, item.id));
    }
    for (const item of slides.docs) {
      if (!item.data().deleted) tx.update(item.ref, {'value.category': to, updatedAt: FieldValue.serverTimestamp()});
    }
    // Serialize against slide edits; no client-side bulk save that overwrites peers.
    tx.set(db.doc(`${root}/libraryState/index`), {...index.data(), updatedAt: FieldValue.serverTimestamp()});
    tx.delete(doc(from));
    if (to) tx.set(doc(to), {name: to, updatedAt: FieldValue.serverTimestamp()});
    return {changed: workouts.size + slides.size};
  });
}
