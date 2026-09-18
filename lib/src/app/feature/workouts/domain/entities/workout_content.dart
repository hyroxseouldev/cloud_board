import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

part 'workout_content.freezed.dart';

/// Editable content. Account preferences never belong to this value.
@freezed
abstract class WorkoutContent with _$WorkoutContent {
  const WorkoutContent._();
  const factory WorkoutContent({
    required String id,
    required String ownerId,
    required WorkoutAuthor author,
    required String name,
    required String folder,
    required List<WorkoutModule> modules,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _WorkoutContent;

  factory WorkoutContent.fromWorkout(Workout value) => WorkoutContent(
    id: value.id,
    ownerId: value.ownerId,
    author: value.author,
    name: value.name,
    folder: value.folder,
    modules: value.modules,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  // Rendering adapter for existing slide/timer widgets. Not a persistence DTO.
  Workout toWorkout() => Workout.empty(id, author).copyWith(
    ownerId: ownerId,
    name: name,
    folder: folder,
    modules: modules,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
