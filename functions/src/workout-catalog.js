// The projection deliberately excludes modules, author and all editor content.
// Keep duration semantics identical to Dart workout_metrics.dart.
export function summarizeWorkout(data, id = data.id) {
  const modules = data.modules || [];
  const durationSeconds = modules.reduce((total, module) => {
    const blocks = module.intervalBlocks?.length ? module.intervalBlocks : [module];
    return total + blocks.reduce((sum, block) => sum +
      block.workSeconds * block.sets + block.restSeconds * (block.sets - 1), 0);
  }, 0);
  const summary = {
    id, name: data.name || '', folder: data.folder || '',
    // Firestore serializes WorkoutModuleModel.imageUrl. Preserve an explicit
    // empty imageUrl (image removed); imageSource is only a legacy fallback.
    imageSource: modules[0]?.imageUrl ?? modules[0]?.imageSource ?? '', moduleCount: modules.length,
    durationSeconds, updatedAt: data.updatedAt,
  };
  if (!summary.updatedAt || !Number.isFinite(durationSeconds)) {
    throw new Error('invalid-workout-projection');
  }
  return summary;
}

function equivalent(a, b) {
  if (!a || !b) return a === b;
  return Object.keys(b).length === Object.keys(a).length && Object.keys(b).every(key =>
    key === 'updatedAt' ? a[key]?.isEqual?.(b[key]) === true : a[key] === b[key]);
}

// Read the CURRENT document in a transaction, not a trigger's possibly stale
// event body. Retries/out-of-order delivery and concurrent edits are safe.
export async function syncWorkoutSummary(db, uid, id) {
  const workout = db.doc(`users/${uid}/workouts/${id}`);
  const summary = db.doc(`users/${uid}/workoutSummaries/${id}`);
  return db.runTransaction(async tx => {
    const [source, target, deleting] = await Promise.all([
      tx.get(workout), tx.get(summary), tx.get(db.doc(`accountDeletions/${uid}`)),
    ]);
    if (deleting.exists) return false;
    if (!source.exists) {
      if (target.exists) tx.delete(summary);
      return target.exists;
    }
    const value = summarizeWorkout(source.data(), id);
    if (equivalent(target.data(), value)) return false;
    tx.set(summary, value);
    return true;
  });
}

export async function backfillCatalog(db, uid) {
  const marker = db.doc(`users/${uid}/catalog/schema`);
  const workouts = db.collection(`users/${uid}/workouts`);
  let cursor;
  let checked = 0;
  do {
    let query = workouts.orderBy('__name__').limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    // Bounded work; no unbounded fan-out for large catalogs.
    for (const doc of page.docs) { await syncWorkoutSummary(db, uid, doc.id); checked++; }
    cursor = page.docs.at(-1);
    if (page.size < 100) break;
  } while (cursor);
  // Remove stale summaries via the same transactional current-source check.
  cursor = undefined;
  do {
    let query = db.collection(`users/${uid}/workoutSummaries`).orderBy('__name__').limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) await syncWorkoutSummary(db, uid, doc.id);
    cursor = page.docs.at(-1);
    if (page.size < 100) break;
  } while (cursor);
  await db.runTransaction(async tx => {
    if (!(await tx.get(db.doc(`accountDeletions/${uid}`))).exists) {
      tx.set(marker, {version: 2});
    }
  });
  return checked;
}
