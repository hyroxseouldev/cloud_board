// Pure compatibility policy, shared by dry-run and apply. No IO.
export const legacySettingKeys = ['brandL', 'brandR', 'soundTheme', 'countdownSound',
  'workStartSound', 'restStartSound', 'workoutEndSound', 'soundVolume',
  'countdownSeconds', 'countdownBackgroundColor', 'countdownImageSource', 'countdownAppearance'];
const sounds = ['silent', 'gentleBeep', 'classicBeep', 'sharpBeep', 'lowPulse', 'boxingBell', 'softBell', 'doubleBeep', 'longFinish', 'videoBeep'];
const themes = ['videoBeep', 'simple', 'classic', 'boxing', 'studio', 'custom'];
const appearanceDefaults = {showReady: true, showTitle: true, numberScale: 1,
  numberFormat: 'seconds', numberColor: null, numberShadow: false,
  overlayEnabled: true, overlayOpacity: null, overlayColor: null};
const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
function numeric(value, fallback) {
  if (value == null) return fallback;
  if (typeof value !== 'number' || !Number.isFinite(value)) throw Error('Invalid numeric setting');
  return value;
}
function string(value, fallback = '') {
  if (value == null) return fallback;
  if (typeof value !== 'string') throw Error('Invalid text setting');
  return value;
}
export function normalizeSettings(value) {
  const countdown = value.countdown ?? {};
  const a = {...appearanceDefaults, ...countdown.appearance};
  for (const key of ['showReady', 'showTitle', 'numberShadow', 'overlayEnabled']) {
    if (typeof a[key] !== 'boolean') throw Error(`Invalid ${key}`);
  }
  if (!['seconds', 'clock'].includes(a.numberFormat)) throw Error('Invalid numberFormat');
  for (const key of ['numberColor', 'overlayColor']) {
    if (a[key] !== null && !Number.isInteger(a[key])) throw Error(`Invalid ${key}`);
  }
  a.numberScale = clamp(numeric(a.numberScale, 1), .5, 1.8);
  a.overlayOpacity = a.overlayOpacity == null ? null : clamp(numeric(a.overlayOpacity), 0, 1);
  const result = {brandL: string(value.brandL, 'CloudBoard'), brandR: string(value.brandR),
    soundTheme: value.soundTheme ?? 'videoBeep',
    countdownSound: value.countdownSound ?? 'videoBeep',
    workStartSound: value.workStartSound ?? 'videoBeep',
    restStartSound: value.restStartSound ?? 'videoBeep',
    workoutEndSound: value.workoutEndSound ?? 'videoBeep',
    soundVolume: clamp(numeric(value.soundVolume, 1), 0, 1),
    countdown: {seconds: clamp(Math.trunc(numeric(countdown.seconds, 3)), 0, 60),
      backgroundColor: numeric(countdown.backgroundColor, 0xFF000000),
      imageSource: string(countdown.imageSource),
      appearance: Object.fromEntries(Object.keys(appearanceDefaults).map(k => [k, a[k]]))}};
  if (!themes.includes(result.soundTheme) ||
      !['countdownSound', 'workStartSound', 'restStartSound', 'workoutEndSound'].every(k => sounds.includes(result[k]))) {
    throw Error('Unknown sound setting; manual review required');
  }
  if (!Number.isInteger(result.countdown.backgroundColor)) throw Error('Invalid backgroundColor');
  return result;
}
export function legacySettings(workout) {
  if (workout.schemaVersion === 2) throw Error('Content-only workout without canonical settings');
  // Mirrors the legacy Dart decoder, not the new-workout defaults.
  return normalizeSettings({brandL: workout.brandL, brandR: workout.brandR,
    soundTheme: workout.soundTheme ?? 'classic', countdownSound: workout.countdownSound ?? 'classicBeep',
    workStartSound: workout.workStartSound ?? 'sharpBeep', restStartSound: workout.restStartSound ?? 'lowPulse',
    workoutEndSound: workout.workoutEndSound ?? 'longFinish', soundVolume: workout.soundVolume,
    countdown: {seconds: workout.countdownSeconds, backgroundColor: workout.countdownBackgroundColor,
      imageSource: workout.countdownImageSource, appearance: workout.countdownAppearance}});
}
export function planSettings(user, workouts, canonical) {
  if (canonical) {
    if (canonical.schemaVersion !== 1 || !Number.isInteger(canonical.revision)) throw Error('Unsupported canonical settings');
    return {status: 'already-canonical', preferences: normalizeSettings(canonical.preferences)};
  }
  if (user.workoutSettings) return {status: 'common', preferences: normalizeSettings(user.workoutSettings)};
  if (!workouts.length) return {status: 'empty', preferences: normalizeSettings({countdown: user.countdownDefaults})};
  const variants = new Map(workouts.map(w => {
    const preferences = legacySettings(w);
    return [JSON.stringify(preferences), preferences];
  }));
  return variants.size === 1
    ? {status: 'uniform-legacy', preferences: [...variants.values()][0]}
    : {status: 'needs-selection', variants: variants.size};
}
