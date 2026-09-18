import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_preferences_actions.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
part 'workout_preferences_controller.g.dart';

@riverpod
Future<WorkoutPreferences> accountWorkoutPreferences(
  Ref ref,
  String ownerId,
) async {
  return ref.watch(workoutPreferencesActionsProvider).loadForEditing(ownerId);
}

@riverpod
class WorkoutPreferencesController extends _$WorkoutPreferencesController {
  @override
  AsyncValue<void> build(String ownerId) => const AsyncData(null);
  Future<WorkoutPreferences?> reload() async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () =>
          ref.read(workoutPreferencesActionsProvider).reloadForEditing(ownerId),
    );
    if (!ref.mounted) return null;
    state = result.when(
      data: (_) => const AsyncData(null),
      error: (e, s) => AsyncError(e, s),
      loading: () => const AsyncLoading(),
    );
    return result.value;
  }

  Future<WorkoutPreferences?> save(WorkoutPreferences value) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(workoutPreferencesActionsProvider).save(ownerId, value),
    );
    if (!ref.mounted) return null;
    state = result.when(
      data: (_) => const AsyncData(null),
      error: (e, s) => AsyncError(e, s),
      loading: () => const AsyncLoading(),
    );
    if (!result.hasError) {
      ref.invalidate(accountWorkoutPreferencesProvider(ownerId));
      ref.invalidate(workoutPreviewProvider);
    }
    return result.value;
  }
}

/// Derived rendering only. Raw detail providers remain independent of settings.
@riverpod
Future<Workout> workoutPreview(Ref ref, Workout workout) async {
  final link = ref.keepAlive();
  try {
    return await ref.watch(workoutPreferencesActionsProvider).apply(workout);
  } finally {
    link.close();
  }
}

@riverpod
Future<Workout?> localPlaybackWorkout(Ref ref, String id) async {
  final actions = ref.watch(workoutPreferencesActionsProvider);
  final raw = await ref.watch(workoutDetailProvider(id).future);
  return raw == null ? null : actions.apply(raw);
}
