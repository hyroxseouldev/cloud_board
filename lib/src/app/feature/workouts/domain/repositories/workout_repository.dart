import '../entities/workout.dart';

abstract interface class WorkoutRepository {
  Future<List<Workout>> load();
  Future<void> save(Workout workout);
  Future<void> delete(String workoutId);
}
