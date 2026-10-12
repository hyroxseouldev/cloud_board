import {isDeepStrictEqual} from 'node:util';
import {FieldValue} from 'firebase-admin/firestore';
import {normalizeSettings} from './workout-settings-migration.js';

// Installed clients predate the canonical document. Keep accepting their
// validated profile writes without making an old event overwrite a newer edit.
export function legacyPreferencesChange(before, after, canonical) {
  if (!after || !canonical || canonical.schemaVersion !== 1) return null;
  const settingsChanged = !isDeepStrictEqual(before?.workoutSettings, after.workoutSettings);
  const countdownChanged = !isDeepStrictEqual(before?.countdownDefaults, after.countdownDefaults);
  if (!settingsChanged && !countdownChanged) return null;
  const source = settingsChanged ? after.workoutSettings : {
    ...canonical.preferences, countdown: after.countdownDefaults,
  };
  if (!source) return null;
  const preferences = normalizeSettings(source);
  return canonical.contentOnly === true || !isDeepStrictEqual(preferences, canonical.preferences)
    ? preferences : null;
}

export async function syncLegacyWorkoutSettings(db, uid, before, after, updateTime) {
  if (!after || !updateTime) return false;
  const profileRef = db.doc(`users/${uid}`);
  const settingsRef = profileRef.collection('settings').doc('workout');
  return db.runTransaction(async tx => {
    const [profile, settings, deletion] = await Promise.all([
      tx.get(profileRef), tx.get(settingsRef), tx.get(db.doc(`accountDeletions/${uid}`)),
    ]);
    if (deletion.exists || !profile.exists || !settings.exists) return false;
    // A later unrelated profile edit must not lose a pending settings change.
    // A later settings edit, however, always wins over this delivered event.
    if (!isDeepStrictEqual(profile.data().workoutSettings, after.workoutSettings)
      || !isDeepStrictEqual(profile.data().countdownDefaults, after.countdownDefaults)) return false;
    const canonicalTime = settings.data().updatedAt;
    if (canonicalTime && (canonicalTime.seconds > updateTime.seconds
      || (canonicalTime.seconds === updateTime.seconds && canonicalTime.nanoseconds > updateTime.nanoseconds))) return false;
    const preferences = legacyPreferencesChange(before, after, settings.data());
    if (!preferences) return false;
    tx.update(settingsRef, {preferences, contentOnly: false,
      revision: settings.data().revision + 1, updatedAt: FieldValue.serverTimestamp()});
    if (!isDeepStrictEqual(profile.data().workoutSettings, preferences)) {
      tx.update(profileRef, {workoutSettings: preferences});
    }
    return true;
  });
}
