import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_repository_impl.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';

part 'workout_actions.g.dart';

class LoadWorkouts {
  const LoadWorkouts(this._repository);
  final WorkoutRepository _repository;
  Future<List<WorkoutSummary>> call() => watch().last;
  Stream<List<WorkoutSummary>> watch() => _repository.watchSummaries();
  // Always return persisted content/legacy fields, never account overrides.
  Future<Workout?> detail(String id) => _repository.loadOne(id);
}

class SaveWorkout {
  const SaveWorkout(this._repository);
  final WorkoutRepository _repository;
  Future<Workout> call(Workout workout) => _repository.save(workout);
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
