import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';

String durationLabel(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

int intervalBlockDuration(WorkoutIntervalBlock block) =>
    (block.workSeconds * block.sets) + (block.restSeconds * (block.sets - 1));

int workoutModuleDuration(WorkoutModule module) =>
    effectiveIntervalBlocks(module)
        .fold(0, (sum, block) => sum + intervalBlockDuration(block));

int workoutDuration(Workout workout) => workout.modules.fold(
  0,
  (sum, module) => sum + workoutModuleDuration(module),
);

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
