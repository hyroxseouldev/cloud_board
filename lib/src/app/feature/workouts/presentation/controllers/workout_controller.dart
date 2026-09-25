import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_edit_access.dart';

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';

part 'workout_controller.g.dart';

@riverpod
class WorkoutUploadProgress extends _$WorkoutUploadProgress {
  @override
  ({int completed, int total})? build() => null;
  void update(int completed, int total) =>
      state = (completed: completed, total: total);
  void reset() => state = null;
}

String workoutSaveProgressLabel(({int completed, int total})? progress) =>
    progress != null &&
        progress.total > 0 &&
        progress.completed < progress.total
    ? '이미지 ${progress.completed}/${progress.total} 저장 중'
    : '저장 중';

@riverpod
class WorkoutDetail extends _$WorkoutDetail {
  int _writes = 0;
  @override
  Future<Workout?> build(String id) async {
    // Play/duplicate/scheduled starts may request a detail before any route
    // watches it. Keep that one-shot request alive until it resolves.
    final request = ref.keepAlive();
    final version = _writes;
    try {
      final user = await ref.watch(authStateProvider.future);
      if (user == null) return null;
      final value = await (await ref.watch(loadWorkoutsProvider.future))
          .detail(id);
      return version == _writes ? value : state.value;
    } finally {
      request.close();
    }
  }

  // A successful save updates the open editor without a loading transition
  // that would unmount its unsaved draft.
  void replace(Workout? value) {
    // Bridge /editor/new -> /editor/<id> without throwing away the just-saved
    // detail while no route has subscribed yet. This cache is strictly bounded.
    final link = ref.keepAlive();
    final timer = Timer(const Duration(seconds: 30), link.close);
    ref.onDispose(timer.cancel);
    _writes++;
    state = AsyncData(value);
  }
}

@Riverpod(keepAlive: true)
class WorkoutController extends _$WorkoutController {
  final _upserts = <String, WorkoutSummary>{};
  final _removed = <String>{};
  Future<void>? _loading;

  @override
  Stream<List<WorkoutSummary>> build() async* {
    _upserts.clear();
    _removed.clear();
    final complete = Completer<void>();
    _loading = complete.future;
    try {
      final user = await ref.watch(authStateProvider.future);
      if (user == null) {
        yield const [];
        return;
      }
      final loader = await ref.watch(loadWorkoutsProvider.future);
      await for (final items in loader.watch()) {
        yield _merge(items);
      }
    } finally {
      complete.complete();
    }
  }

  // A scheduled start must not mistake the first page for the complete catalog.
  Future<List<WorkoutSummary>> loadComplete() async {
    await future;
    await _loading;
    return state.requireValue;
  }

  /// Reload cache and server pages, completing only after the full catalog arrives.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await loadComplete();
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  List<WorkoutSummary> _merge(List<WorkoutSummary> items) {
    final merged = {for (final item in items) item.id: item, ..._upserts};
    for (final id in _removed) {
      merged.remove(id);
    }
    return merged.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void upsert(Workout workout) {
    final summary = summarizeWorkout(workout);
    _upserts[workout.id] = summary;
    _removed.remove(workout.id);
    final items = state.value;
    if (items == null) return;
    final index = items.indexWhere((item) => item.id == workout.id);
    final next = [...items];
    if (index == -1) {
      next.insert(0, summary);
    } else {
      next[index] = summary;
    }
    state = AsyncData(next);
  }

  void remove(String workoutId) {
    _upserts.remove(workoutId);
    _removed.add(workoutId);
    final items = state.value;
    if (items == null) return;
    state = AsyncData(
      items.where((item) => item.id != workoutId).toList(growable: false),
    );
  }
}

@riverpod
class WorkoutActionController extends _$WorkoutActionController {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  /// Keep the existing action overlay active while fetching a detail for play
  /// or duplicate, so repeated taps cannot open multiple preparation dialogs.
  Future<Workout?> prepare(String id) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    Workout? detail;
    final subscription = ref.listen(workoutDetailProvider(id), (_, _) {});
    final result = await AsyncValue.guard<String?>(() async {
      detail = await ref.read(workoutDetailProvider(id).future);
      if (detail == null) throw StateError('워크아웃을 찾을 수 없습니다.');
      return null;
    });
    subscription.close();
    if (!ref.mounted) return null;
    state = result;
    return result.hasError ? null : detail;
  }

  Future<Workout?> save(Workout workout) async {
    if (state.isLoading) return null;
    ref.read(workoutUploadProgressProvider.notifier).reset();
    state = const AsyncLoading();
    Workout? saved;
    state = await AsyncValue.guard(() async {
      final value = workout.copyWith(updatedAt: DateTime.now());
      await _ensureEditable(workout.id);
      final save = await ref.read(saveWorkoutProvider.future);
      await _ensureEditable(workout.id);
      saved = await save(
        value,
        onProgress: (completed, total) {
          if (ref.mounted) {
            ref
                .read(workoutUploadProgressProvider.notifier)
                .update(completed, total);
          }
        },
      );
      ref.read(workoutDetailProvider(saved!.id).notifier).replace(saved);
      ref.read(workoutControllerProvider.notifier).upsert(saved!);
      return '워크아웃을 저장했습니다.';
    });
    return state.hasError ? null : saved;
  }

  Future<bool> delete(String workoutId) => _run(
    successMessage: '워크아웃을 삭제했습니다.',
    action: () async {
      await _ensureEditable(workoutId);
      final delete = await ref.read(deleteWorkoutProvider.future);
      await _ensureEditable(workoutId);
      await delete(workoutId);
      ref.read(workoutDetailProvider(workoutId).notifier).replace(null);
      ref.read(workoutControllerProvider.notifier).remove(workoutId);
    },
  );

  Future<bool> duplicate(Workout workout, String newId) => _run(
    successMessage: '워크아웃을 복사했습니다.',
    action: () async {
      final duplicate = workout.copyWith(
        id: newId,
        name: '${workout.name} 복사',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        modules: workout.modules
            .map((item) => item.copyWith(id: '${item.id}c'))
            .toList(),
      );
      final saved = await (await ref.read(saveWorkoutProvider.future))(
        duplicate,
      );
      ref.read(workoutDetailProvider(saved.id).notifier).replace(saved);
      ref.read(workoutControllerProvider.notifier).upsert(saved);
    },
  );

  Future<void> _ensureEditable(String workoutId) async {
    // Riverpod pauses unobserved streams. Keep this check subscribed even when
    // a save originates outside the currently visible editor.
    final subscription = ref.listen(activePlaybackSessionProvider, (_, _) {});
    try {
      final current = ref.read(activePlaybackSessionProvider);
      if (current.isLoading) {
        await ref
            .read(activePlaybackSessionProvider.future)
            .timeout(const Duration(seconds: 8));
      }
      final reason = workoutEditBlockReason(
        ref.read(activePlaybackSessionProvider),
        workoutId,
      );
      if (reason != null) throw StateError(reason);
    } finally {
      subscription.close();
    }
  }

  Future<bool> _run({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await action();
      return successMessage;
    });
    return !state.hasError;
  }
}
