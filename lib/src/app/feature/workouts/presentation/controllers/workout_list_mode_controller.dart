import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
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

/// Presentation preference, independent of continuous/paged catalog fetching.
/// Existing browsing-mode values retain their meaning.
enum HomeWorkoutLayout { list, grid }

final homeWorkoutLayoutStoreProvider = Provider<HomeWorkoutLayoutStore>(
  (_) => HomeWorkoutLayoutStore(),
);

class HomeWorkoutLayoutStore {
  String key(String ownerId) => 'home.workoutLayout.v1.$ownerId';
  Future<HomeWorkoutLayout?> read(String ownerId) async {
    final value = (await SharedPreferences.getInstance()).getString(
      key(ownerId),
    );
    return HomeWorkoutLayout.values
        .where((layout) => layout.name == value)
        .firstOrNull;
  }

  Future<bool> write(String ownerId, HomeWorkoutLayout layout) async =>
      (await SharedPreferences.getInstance()).setString(
        key(ownerId),
        layout.name,
      );
}

final homeWorkoutLayoutProvider =
    NotifierProvider<HomeWorkoutLayoutController, HomeWorkoutLayout>(
      HomeWorkoutLayoutController.new,
    );

class HomeWorkoutLayoutController extends Notifier<HomeWorkoutLayout> {
  int _epoch = 0;
  Future<void> _writes = Future.value();
  @override
  HomeWorkoutLayout build() {
    final owner = ref.watch(
      authStateProvider.select((value) => value.value?.id),
    );
    final store = ref.watch(homeWorkoutLayoutStoreProvider);
    final epoch = ++_epoch;
    if (owner != null) {
      unawaited(_restore(store, owner, epoch));
    }
    return HomeWorkoutLayout.grid;
  }

  Future<void> _restore(
    HomeWorkoutLayoutStore store,
    String owner,
    int epoch,
  ) async {
    try {
      await _writes;
      final saved = await store.read(owner);
      if (ref.mounted && epoch == _epoch && saved != null) state = saved;
    } catch (_) {
      // Unavailable local preferences leave the explicit default in place.
      // This is not account/catalog storage and never initiates a server write.
    }
  }

  Future<bool> select(HomeWorkoutLayout layout) async {
    final owner = ref.read(authStateProvider).value?.id;
    ++_epoch; // A late disk read must not replace a user selection.
    state = layout;
    if (owner == null) return false;
    final store = ref.read(homeWorkoutLayoutStoreProvider);
    var saved = false;
    _writes = _writes.then((_) async {
      try {
        saved = await store.write(owner, layout);
      } catch (_) {
        saved = false;
      }
    });
    await _writes;
    return saved;
  }
}
