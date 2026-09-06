import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

String durationLabel(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

int workoutDuration(Workout workout) => workout.modules.fold(
  0,
  (sum, module) =>
      sum +
      (module.workSeconds * module.sets) +
      (module.restSeconds * (module.sets - 1)),
);

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
