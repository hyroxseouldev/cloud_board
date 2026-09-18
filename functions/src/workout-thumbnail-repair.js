import {summarizeWorkout} from './workout-catalog.js';

// Repair only missing thumbnails on existing summaries. Never rewrite workouts,
// ordering timestamps, catalog markers, sessions, or a nonempty thumbnail.
export async function repairWorkoutThumbnail(db, uid, id, {apply = false, backup} = {}) {
  return db.runTransaction(async tx => {
    const sourceRef = db.doc(`users/${uid}/workouts/${id}`);
    const summaryRef = db.doc(`users/${uid}/workoutSummaries/${id}`);
    const [source, summary, deleting] = await Promise.all([
      tx.get(sourceRef), tx.get(summaryRef), tx.get(db.doc(`accountDeletions/${uid}`)),
    ]);
    if (deleting.exists || !source.exists || !summary.exists) return 'skipped';
    const expected = summarizeWorkout(source.data(), id).imageSource;
    const actual = summary.data().imageSource;
    if (typeof expected !== 'string' || !expected || (actual != null && actual !== '')) return 'unchanged';
    if (!apply) return 'candidate';
    if (!backup) throw new Error('Thumbnail repair requires a durable backup before writing.');
    // The callback must tolerate retries; every transaction attempt is backed up.
    await backup({uid, id, source: source.data(), summary: summary.data(), expected});
    tx.update(summaryRef, {imageSource: expected});
    return 'repaired';
  });
}
