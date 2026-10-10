import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/exploration_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/import_starter_workout.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

part 'starter_workout_controller.g.dart';

@riverpod
class StarterWorkoutController extends _$StarterWorkoutController {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  Future<Workout?> import(StarterWorkout template, {bool owned = false}) async {
    if (state.isLoading) return null;
    final keepAlive = ref.keepAlive();
    final reporter = ref.read(errorReporterProvider);
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
        owned: owned,
      );
      if (!ref.mounted || ref.read(authStateProvider).value?.id != user.id) {
        return null;
      }
      ref.read(workoutDetailProvider(saved!.id).notifier).replace(saved);
      ref.read(workoutControllerProvider.notifier).upsert(saved!);
      if (owned) {
        unawaited(
          ref
              .read(explorationControllerProvider.notifier)
              .imported(template)
              .catchError((Object _) {}),
        );
      }
      final firstClass = ref.read(firstClassControllerProvider.notifier);
      unawaited(
        () async {
          await firstClass.saved(saved!.id, ownerId: saved!.ownerId);
          if (owned) {
            await firstClass.learningEvent(
              'starter_to_owned',
              ownerId: saved!.ownerId,
            );
          }
        }().catchError((Object _) {}),
      );
      return saved!.id;
    });
    if (result.hasError) {
      reporter.capture(
        result.error!,
        result.stackTrace ?? StackTrace.current,
        action: 'workout.save',
        context: {'workoutId': template.workoutId, 'source': 'starter_import'},
      );
    }
    if (ref.mounted) state = result;
    keepAlive.close();
    return result.hasError || result.value == null ? null : saved;
  }
}
