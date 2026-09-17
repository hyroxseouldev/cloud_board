import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
part 'workout_summary.freezed.dart';

/// List/search data only. Never pass this projection to an editor or player.
@freezed
abstract class WorkoutSummary with _$WorkoutSummary {
  const factory WorkoutSummary({
    required String id,
    required String name,
    required String folder,
    required String imageSource,
    required int moduleCount,
    required int durationSeconds,
    required DateTime updatedAt,
  }) = _WorkoutSummary;
}

WorkoutSummary summarizeWorkout(Workout workout) => WorkoutSummary(
  id: workout.id,
  name: workout.name,
  folder: workout.folder,
  imageSource: workout.modules.firstOrNull?.imageSource ?? '',
  moduleCount: workout.modules.length,
  durationSeconds: workoutDuration(workout),
  updatedAt: workout.updatedAt,
);
