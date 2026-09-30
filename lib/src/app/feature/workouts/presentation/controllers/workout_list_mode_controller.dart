import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workout_list_mode_controller.g.dart';

enum WorkoutListMode { continuous, paged }

// Keep both browsing modes available without exposing the preference yet.
// Enable the menu with --dart-define=SHOW_WORKOUT_LIST_MODE_SELECTOR=true.
// Preview pagination directly with --dart-define=WORKOUT_LIST_PAGED=true.
@riverpod
bool workoutListModeSelectorEnabled(Ref ref) =>
    const bool.fromEnvironment('SHOW_WORKOUT_LIST_MODE_SELECTOR');

@Riverpod(keepAlive: true)
class WorkoutListModeController extends _$WorkoutListModeController {
  @override
  WorkoutListMode build() => const bool.fromEnvironment('WORKOUT_LIST_PAGED')
      ? WorkoutListMode.paged
      : WorkoutListMode.continuous;

  void select(WorkoutListMode mode) => state = mode;
}
