import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

abstract interface class WorkoutRepository {
  Future<List<Workout>> load();
  Stream<List<Workout>> watch();
  Future<Workout> save(Workout workout);
  Future<void> delete(String workoutId);
}
