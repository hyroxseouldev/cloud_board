import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';

class SlideRehearsalFrame {
  const SlideRehearsalFrame({
    required this.blockIndex,
    required this.set,
    required this.totalSets,
    required this.isRest,
    required this.durationMs,
    required this.remainingMs,
    required this.startMs,
    this.positionLabel,
  });
  final int blockIndex, set, totalSets, durationMs, remainingMs, startMs;
  final bool isRest;
  final String? positionLabel;
  int get secondsLeft => (remainingMs / 1000).ceil();
}

SlideRehearsalFrame rehearsalFrame(WorkoutModule module, int positionMs) {
  if (isOpenEndedTimer(module)) {
    return SlideRehearsalFrame(
      blockIndex: 0,
      set: 1,
      totalSets: 1,
      isRest: false,
      durationMs: 0,
      remainingMs: positionMs < 0 ? 0 : positionMs,
      startMs: 0,
      positionLabel: 'For Time',
    );
  }
  final phases = workoutModuleTimeline(module);
  final total = workoutModuleDuration(module) * 1000;
  var position = positionMs.clamp(0, total);
  var start = 0;
  for (var i = 0; i < phases.length; i++) {
    final phase = phases[i];
    final duration = phase.seconds * 1000;
    if (position < duration || i == phases.length - 1) {
      return SlideRehearsalFrame(
        blockIndex: phase.blockIndex,
        set: phase.set,
        totalSets: phase.totalSets,
        isRest: phase.isRest,
        durationMs: duration,
        remainingMs: (duration - position).clamp(0, duration),
        startMs: start,
        positionLabel: workoutPhaseLabel(module, phase),
      );
    }
    start += duration;
    position -= duration;
  }
  return const SlideRehearsalFrame(
    blockIndex: 0,
    set: 1,
    totalSets: 1,
    isRest: false,
    durationMs: 0,
    remainingMs: 0,
    startMs: 0,
  );
}
