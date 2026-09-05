import '../entities/workout.dart';

abstract interface class WorkoutRepository {
  Future<List<Workout>> load();
  Future<Workout> save(Workout workout);
  Future<void> delete(String workoutId);
}
