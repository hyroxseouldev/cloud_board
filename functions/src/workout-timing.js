// Match domain/workout_timeline.dart. Persistent round definitions are compact;
// bound their expansion before allocating a playback timeline.
export const timingLimits = {seconds: 59999, repeats: 999, blocks: 100, steps: 10000};
const integer = (v, min, max) => Number.isSafeInteger(v) && v >= min && v <= max;
const blocksOf = m => m.intervalBlocks?.length ? m.intervalBlocks : [m];
export const isOpenEndedTimer = m => m.timerMode === 'forTime' && m.workSeconds === 0;
const hasRest = (m, b, set) => b.restSeconds > 0 &&
  ((m.timingVersion >= 2 && b.workSeconds === 0) || m.includeFinalRest !== false || set < b.sets);

export function validateWorkoutTiming(m) {
  const version = m.timingVersion ?? 1;
  const rounds = m.rounds ?? 1;
  const rest = m.roundRestSeconds ?? 0;
  const blocks = blocksOf(m);
  const mode = m.timerMode ?? 'custom';
  const direction = m.timerDirection ?? 'down';
  if (![1, 2, 3].includes(version) ||
      !['custom', 'emom', 'amrap', 'forTime', 'tabata', 'interval'].includes(mode) ||
      !['up', 'down'].includes(direction) ||
      (version < 3 && (mode !== 'custom' || direction !== 'down')) ||
      !integer(rounds, 1, timingLimits.repeats) ||
      !integer(rest, 0, timingLimits.seconds) || !Array.isArray(blocks) || blocks.length > timingLimits.blocks ||
      (m.includeFinalRoundRest !== undefined && typeof m.includeFinalRoundRest !== 'boolean') ||
      (m.includeFinalRest !== undefined && typeof m.includeFinalRest !== 'boolean') ||
      (version === 1 && (rounds !== 1 || rest !== 0))) return false;
  if (mode === 'amrap' || mode === 'forTime') {
    if (rounds !== 1 || rest !== 0 || m.sets !== 1 || m.restSeconds !== 0 ||
        (m.intervalBlocks?.length ?? 0) !== 0 ||
        !integer(m.workSeconds, mode === 'amrap' ? 1 : 0, timingLimits.seconds)) return false;
    if (isOpenEndedTimer(m)) return direction === 'up';
  }
  let steps = 0;
  for (const b of blocks) {
    if (!b || !integer(b.workSeconds, version >= 2 ? 0 : 1, timingLimits.seconds) ||
        !integer(b.restSeconds, 0, timingLimits.seconds) ||
        !integer(b.sets, 1, timingLimits.repeats) || b.workSeconds + b.restSeconds === 0) return false;
    steps += (b.workSeconds > 0 ? b.sets : 0) +
      (b.restSeconds > 0 ? (hasRest(m, b, b.sets) ? b.sets : b.sets - 1) : 0);
  }
  return steps * rounds + (rest > 0 ? rounds - (m.includeFinalRoundRest === false ? 1 : 0) : 0) <= timingLimits.steps;
}

export function workoutTimingDuration(m) {
  // Preserve the old catalog projection for legacy data. New writes validate
  // v2 timing before accepting saved templates and before local persistence.
  if ((m.timingVersion ?? 1) >= 2 && !validateWorkoutTiming(m)) {
    throw new Error('invalid-workout-timing');
  }
  const perRound = blocksOf(m).reduce((sum, b) => sum + b.workSeconds * b.sets +
    b.restSeconds * (hasRest(m, b, b.sets) ? b.sets : b.sets - 1), 0);
  const rounds = m.rounds ?? 1;
  return perRound * rounds + (m.roundRestSeconds ?? 0) *
    (rounds - (m.includeFinalRoundRest === false ? 1 : 0));
}

export function expandWorkoutTiming(m) {
  if (!validateWorkoutTiming(m)) throw new Error('invalid-workout-timing');
  if (isOpenEndedTimer(m)) return [{seconds: 0, isRest: false, round: 1, interval: 1}];
  const phases = [];
  const blocks = blocksOf(m);
  const rounds = m.rounds ?? 1;
  for (let round = 1; round <= rounds; round++) {
    let interval = 0;
    for (const b of blocks) {
      for (let set = 1; set <= b.sets; set++) {
        interval++;
        if (b.workSeconds > 0) phases.push({seconds: b.workSeconds, isRest: false, round, interval});
        if (hasRest(m, b, set)) phases.push({seconds: b.restSeconds, isRest: true, round, interval});
      }
    }
    if (m.roundRestSeconds > 0 && (round < rounds || m.includeFinalRoundRest !== false)) {
      phases.push({seconds: m.roundRestSeconds, isRest: true, round, interval});
    }
  }
  return phases;
}
