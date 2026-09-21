import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_preferences_repository.dart';

/// Keep the real settings resolver in widget tests, without Firebase SDK access.
class FixtureWorkoutPreferences implements WorkoutPreferencesRepository {
  FixtureWorkoutPreferences({required this.ownerId, this.value});

  final String ownerId;
  WorkoutPreferences? value;
  final loadedOwners = <String>[];

  void _checkOwner(String id) {
    if (id != ownerId) throw StateError('Unexpected settings owner: $id');
  }

  @override
  Future<WorkoutPreferences?> load(String ownerId, {bool fresh = false}) async {
    _checkOwner(ownerId);
    loadedOwners.add(ownerId);
    return value;
  }

  @override
  Future<WorkoutPreferences> loadForEditing(String ownerId) async =>
      await load(ownerId) ?? const WorkoutPreferences();

  @override
  Future<WorkoutPreferences> save(
    String ownerId,
    WorkoutPreferences value,
  ) async {
    _checkOwner(ownerId);
    return this.value = value;
  }
}
