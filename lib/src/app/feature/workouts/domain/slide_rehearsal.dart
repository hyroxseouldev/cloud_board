import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
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
  });
  final int blockIndex, set, totalSets, durationMs, remainingMs, startMs;
  final bool isRest;
  int get secondsLeft => (remainingMs / 1000).ceil();
}

SlideRehearsalFrame rehearsalFrame(WorkoutModule module, int positionMs) {
  final blocks = effectiveIntervalBlocks(module);
  final total = workoutModuleDuration(module) * 1000;
  var position = positionMs.clamp(0, total);
  var start = 0;
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    for (var set = 1; set <= block.sets; set++) {
      for (final rest in [
        false,
        if (set < block.sets && block.restSeconds > 0) true,
      ]) {
        final duration = (rest ? block.restSeconds : block.workSeconds) * 1000;
        final last = i == blocks.length - 1 && set == block.sets;
        if (position < duration || last) {
          return SlideRehearsalFrame(
            blockIndex: i,
            set: set,
            totalSets: block.sets,
            isRest: rest,
            durationMs: duration,
            remainingMs: (duration - position).clamp(0, duration),
            startMs: start,
          );
        }
        start += duration;
        position -= duration;
      }
    }
  }
  throw StateError('시험 재생할 시간 블록이 없습니다.');
}
