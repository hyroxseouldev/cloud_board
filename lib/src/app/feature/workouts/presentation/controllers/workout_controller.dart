import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/workout.dart';
import '../../domain/usecases/workout_actions.dart';

part 'workout_controller.g.dart';

@Riverpod(keepAlive: true)
class WorkoutController extends _$WorkoutController {
  @override
  Future<List<Workout>> build() async =>
      (await ref.watch(loadWorkoutsProvider.future))();

  Future<void> save(Workout workout) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final value = workout.copyWith(updatedAt: DateTime.now());
      await (await ref.read(saveWorkoutProvider.future))(value);
      return (await ref.read(loadWorkoutsProvider.future))();
    });
  }

  Future<void> delete(String workoutId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await (await ref.read(deleteWorkoutProvider.future))(workoutId);
      return (await ref.read(loadWorkoutsProvider.future))();
    });
  }

  Future<void> duplicate(Workout workout, String newId) => save(
    workout.copyWith(
      id: newId,
      name: '${workout.name} 복사',
      modules: workout.modules
          .map((item) => item.copyWith(id: '${item.id}c'))
          .toList(),
    ),
  );
}
