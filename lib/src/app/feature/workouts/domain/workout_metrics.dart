import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';

String durationLabel(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

int workoutModuleDuration(WorkoutModule module) =>
    workoutModuleTimeline(module).fold(0, (sum, phase) => sum + phase.seconds);

int workoutDuration(Workout workout) => workout.modules.fold(
  0,
  (sum, module) => sum + workoutModuleDuration(module),
);

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
