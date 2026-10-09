import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';

import 'dart:math';

import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';

final _forTimeFlags = Expando<List<bool>>();
List<bool> playbackForTimeFlags(Workout workout) => _forTimeFlags[workout] ??= [
  for (final module in workout.modules)
    for (final _ in workoutModuleTimeline(module))
      module.timerMode == WorkoutTimerMode.forTime,
];

List<int> playbackDurations(Workout workout) => [
  for (final module in workout.modules)
    for (final phase in workoutModuleTimeline(module)) phase.seconds * 1000,
];

/// A session anchor stays unchanged as time crosses interval boundaries.
/// All displays/controllers derive the same position without periodic writes.
({int index, int remainingMs, int countdownMs}) playbackPosition(
  PlaybackSession session,
  List<int> durationsMs,
  int serverNowMs,
) {
  var index = session.stepIndex;
  if (session.status != PlaybackStatus.completed &&
      (index < 0 || index >= durationsMs.length || session.remainingMs < 0)) {
    throw const PlaybackFailure(
      'invalid_position',
      '수업의 재생 위치와 슬라이드 데이터가 일치하지 않습니다.',
    );
  }
  if (session.status == PlaybackStatus.completed) {
    return (index: durationsMs.length, remainingMs: 0, countdownMs: 0);
  }
  if (session.status != PlaybackStatus.playing ||
      session.briefing ||
      session.timerCompleted) {
    return (
      index: index,
      remainingMs: session.remainingMs,
      countdownMs: session.briefing ? 0 : session.startDelayMs,
    );
  }
  final elapsed = max<int>(0, serverNowMs - session.anchorServerMs);
  final countdown = max<int>(0, session.startDelayMs - elapsed);
  final runningMs = max<int>(0, elapsed - session.startDelayMs);
  if (durationsMs[index] == 0) {
    return (
      index: index,
      remainingMs: session.remainingMs + runningMs,
      countdownMs: countdown,
    );
  }
  final forTime = playbackForTimeFlags(session.workout);
  var remaining = session.remainingMs - runningMs;
  while (remaining <= 0 && index < durationsMs.length) {
    // A time cap stops on its result; advancing is an explicit coach action.
    if (index < forTime.length && forTime[index]) {
      return (index: index, remainingMs: 0, countdownMs: countdown);
    }
    index++;
    if (index < durationsMs.length) {
      if (durationsMs[index] == 0) {
        return (index: index, remainingMs: -remaining, countdownMs: countdown);
      }
      remaining += durationsMs[index];
    }
  }
  return (
    index: index,
    remainingMs: max<int>(0, remaining),
    countdownMs: countdown,
  );
}

/// v4 understands explicit rests and round repetition; simple timers can still
/// play on older displays with the same historical final-rest policy.
int requiredTimingProtocol(Workout workout) {
  if (workout.modules.any((m) => m.timingVersion >= 3)) return 5;
  if (workout.modules.any(needsExtendedTiming)) return 4;
  if (workout.modules.any(
    (m) =>
        m.includeFinalRest &&
        (m.restSeconds > 0 || m.intervalBlocks.any((b) => b.restSeconds > 0)),
  )) {
    return 3;
  }
  return 1;
}
