import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_content.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';

part 'workout_playback_snapshot.freezed.dart';

/// Fixed at start; later account edits cannot mutate an active class.
@freezed
abstract class WorkoutPlaybackSnapshot with _$WorkoutPlaybackSnapshot {
  const WorkoutPlaybackSnapshot._();
  const factory WorkoutPlaybackSnapshot({
    required WorkoutContent content,
    required WorkoutPreferences settings,
    required bool usesAccountSettings,
  }) = _WorkoutPlaybackSnapshot;

  Workout toWorkout() => settings.applyTo(content.toWorkout());
}
