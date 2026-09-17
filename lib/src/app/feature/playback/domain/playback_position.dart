import 'dart:math';

import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';

List<int> playbackDurations(Workout workout) => [
  for (final module in workout.modules)
    for (final block in effectiveIntervalBlocks(module))
      for (var set = 1; set <= max<int>(1, block.sets); set++) ...[
        max<int>(1, block.workSeconds) * 1000,
        if (set < block.sets && block.restSeconds > 0) block.restSeconds * 1000,
      ],
];

/// A session anchor stays unchanged as time crosses interval boundaries.
/// All displays/controllers derive the same position without periodic writes.
({int index, int remainingMs, int countdownMs}) playbackPosition(
  PlaybackSession session,
  List<int> durationsMs,
  int serverNowMs,
) {
  var index = session.stepIndex.clamp(0, durationsMs.length);
  if (session.status == PlaybackStatus.completed) {
    return (index: durationsMs.length, remainingMs: 0, countdownMs: 0);
  }
  if (session.status != PlaybackStatus.playing || session.briefing) {
    return (index: index, remainingMs: session.remainingMs, countdownMs: 0);
  }
  final elapsed = max<int>(0, serverNowMs - session.anchorServerMs);
  final countdown = max<int>(0, session.startDelayMs - elapsed);
  var remaining =
      session.remainingMs - max<int>(0, elapsed - session.startDelayMs);
  while (remaining <= 0 && index < durationsMs.length) {
    index++;
    if (index < durationsMs.length) remaining += durationsMs[index];
  }
  return (
    index: index,
    remainingMs: max<int>(0, remaining),
    countdownMs: countdown,
  );
}
