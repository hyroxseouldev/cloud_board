import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';

abstract interface class WorkoutPreferencesRepository {
  Future<WorkoutPreferences?> load(String ownerId, {bool fresh = false});
  Future<WorkoutPreferences> loadForEditing(String ownerId);
  Future<WorkoutPreferences> save(String ownerId, WorkoutPreferences value);
}
