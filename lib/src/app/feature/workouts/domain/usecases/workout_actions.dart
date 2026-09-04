import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../entities/workout.dart';
import '../repositories/workout_repository.dart';
import '../../data/repositories/workout_repository_impl.dart';

part 'workout_actions.g.dart';

class LoadWorkouts {
  const LoadWorkouts(this._repository);
  final WorkoutRepository _repository;
  Future<List<Workout>> call() => _repository.load();
}

class SaveWorkout {
  const SaveWorkout(this._repository);
  final WorkoutRepository _repository;
  Future<void> call(Workout workout) => _repository.save(workout);
}

class DeleteWorkout {
  const DeleteWorkout(this._repository);
  final WorkoutRepository _repository;
  Future<void> call(String id) => _repository.delete(id);
}

@riverpod
Future<LoadWorkouts> loadWorkouts(Ref ref) async =>
    LoadWorkouts(await ref.watch(workoutRepositoryProvider.future));
@riverpod
Future<SaveWorkout> saveWorkout(Ref ref) async =>
    SaveWorkout(await ref.watch(workoutRepositoryProvider.future));
@riverpod
Future<DeleteWorkout> deleteWorkout(Ref ref) async =>
    DeleteWorkout(await ref.watch(workoutRepositoryProvider.future));
