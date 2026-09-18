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
  Future<void> save(String ownerId, WorkoutPreferences value) =>
      repository.save(ownerId, value);
  Future<Workout> apply(Workout workout, {bool fresh = false}) async {
    final settings = await repository.load(workout.ownerId, fresh: fresh);
    // Preserve legacy workouts until the account explicitly saves common settings.
    return settings?.applyTo(workout) ?? workout;
  }
}

@riverpod
WorkoutPreferencesActions workoutPreferencesActions(Ref ref) =>
    WorkoutPreferencesActions(ref.watch(workoutPreferencesRepositoryProvider));
