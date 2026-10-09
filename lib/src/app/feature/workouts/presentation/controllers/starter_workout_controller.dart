import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/import_starter_workout.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

part 'starter_workout_controller.g.dart';

@riverpod
class StarterWorkoutController extends _$StarterWorkoutController {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  Future<Workout?> import(StarterWorkout template) async {
    if (state.isLoading) return null;
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    Workout? saved;
    final result = await AsyncValue.guard(() async {
      final scope = await ref.read(firstClassScopeProvider.future);
      final user = ref.read(authStateProvider).value;
      if (scope == null || user == null || user.id != scope.userId) {
        throw StateError('센터 소유자 계정에서 예시 수업을 가져올 수 있습니다.');
      }
      final importer = await ref.read(importStarterWorkoutProvider.future);
      saved = await importer(
        template,
        WorkoutAuthor(
          id: user.id,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
        ),
      );
      if (!ref.mounted || ref.read(authStateProvider).value?.id != user.id) {
        return null;
      }
      ref.read(workoutDetailProvider(saved!.id).notifier).replace(saved);
      ref.read(workoutControllerProvider.notifier).upsert(saved!);
      unawaited(
        ref
            .read(firstClassControllerProvider.notifier)
            .saved(saved!.id, ownerId: saved!.ownerId)
            .catchError((Object _) {}),
      );
      return saved!.id;
    });
    if (ref.mounted) state = result;
    keepAlive.close();
    return result.hasError || result.value == null ? null : saved;
  }
}
