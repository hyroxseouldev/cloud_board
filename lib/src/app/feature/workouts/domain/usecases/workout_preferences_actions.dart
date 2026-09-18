import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_content.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_playback_snapshot.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_preferences_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_preferences_repository_impl.dart';
part 'workout_preferences_actions.g.dart';

class WorkoutPreferencesActions {
  const WorkoutPreferencesActions(this.repository);
  final WorkoutPreferencesRepository repository;
  Future<WorkoutPreferences?> load(String ownerId) => repository.load(ownerId);
  Future<WorkoutPreferences> loadForEditing(String ownerId) =>
      repository.loadForEditing(ownerId);
  Future<WorkoutPreferences> reloadForEditing(String ownerId) async {
    await repository.load(ownerId, fresh: true);
    return repository.loadForEditing(ownerId);
  }

  Future<WorkoutPreferences> save(String ownerId, WorkoutPreferences value) =>
      repository.save(ownerId, value);
  Future<Workout> apply(Workout workout, {bool fresh = false}) async {
    return (await resolve(workout, fresh: fresh)).toWorkout();
  }

  Future<WorkoutPlaybackSnapshot> resolve(
    Workout workout, {
    bool fresh = false,
  }) async {
    final settings = await repository.load(workout.ownerId, fresh: fresh);
    return WorkoutPlaybackSnapshot(
      content: WorkoutContent.fromWorkout(workout),
      settings: settings ?? WorkoutPreferences.fromWorkout(workout),
      usesAccountSettings: settings != null,
    );
  }
}

@riverpod
WorkoutPreferencesActions workoutPreferencesActions(Ref ref) =>
    WorkoutPreferencesActions(ref.watch(workoutPreferencesRepositoryProvider));
