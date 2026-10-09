import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';

String durationLabel(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

int workoutModuleDuration(WorkoutModule module) =>
    workoutModuleTimeline(module).fold(0, (sum, phase) => sum + phase.seconds);

int workoutDuration(Workout workout) => workout.modules.fold(
  0,
  (sum, module) => sum + workoutModuleDuration(module),
);

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

String workoutDurationKind(Workout workout) =>
    workout.modules.any(isOpenEndedTimer)
    ? 'open'
    : workout.modules.any((m) => m.timerMode == WorkoutTimerMode.forTime)
    ? 'maximum'
    : 'fixed';
String timingDurationLabel(int seconds, String kind) => switch (kind) {
  'open' => seconds == 0 ? '제한시간 없음' : '${durationLabel(seconds)} + 제한시간 없음',
  'maximum' => '최대 ${durationLabel(seconds)}',
  _ => durationLabel(seconds),
};
String workoutDurationText(Workout workout) =>
    timingDurationLabel(workoutDuration(workout), workoutDurationKind(workout));
String moduleDurationText(WorkoutModule module) => timingDurationLabel(
  workoutModuleDuration(module),
  isOpenEndedTimer(module)
      ? 'open'
      : module.timerMode == WorkoutTimerMode.forTime
      ? 'maximum'
      : 'fixed',
);
