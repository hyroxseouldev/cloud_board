import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_preferences_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/countdown_defaults_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
part 'workout_preferences_controller.g.dart';

@riverpod
Future<WorkoutPreferences> accountWorkoutPreferences(
  Ref ref,
  String ownerId,
) async {
  final settings = await ref
      .watch(workoutPreferencesActionsProvider)
      .load(ownerId);
  if (settings != null) return settings;
  return WorkoutPreferences(
    countdown: await ref.watch(countdownDefaultsActionsProvider).load(ownerId),
  );
}

@riverpod
class WorkoutPreferencesController extends _$WorkoutPreferencesController {
  @override
  AsyncValue<void> build(String ownerId) => const AsyncData(null);
  Future<bool> save(WorkoutPreferences value) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(workoutPreferencesActionsProvider).save(ownerId, value),
    );
    if (!ref.mounted) return false;
    state = result;
    if (!result.hasError) {
      ref.invalidate(accountWorkoutPreferencesProvider(ownerId));
      ref.invalidate(workoutDetailProvider);
    }
    return !result.hasError;
  }
}
