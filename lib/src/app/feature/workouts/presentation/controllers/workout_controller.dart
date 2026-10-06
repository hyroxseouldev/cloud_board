import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_edit_access.dart';

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_catalog_page.dart';
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

class CatalogLoadState {
  const CatalogLoadState({
    this.hasMore = false,
    this.loading = false,
    this.error,
  });
  final bool hasMore;
  final bool loading;
  final Object? error;
}

@Riverpod(keepAlive: true)
class WorkoutCatalogStatus extends _$WorkoutCatalogStatus {
  @override
  CatalogLoadState build() => const CatalogLoadState();
  void update(CatalogLoadState value) => state = value;
}

@Riverpod(keepAlive: true)
class WorkoutController extends _$WorkoutController {
  final _upserts = <String, WorkoutSummary>{};
  final _removed = <String>{};
  final _mutationVersions = <String, int>{};
  int _writeVersion = 0;
  int _generation = 0;
  Future<void>? _loading;
  Future<void>? _refreshing;
  StreamIterator<WorkoutCatalogPage>? _pages;
  Future<void>? _nextPage;
  bool _hasMore = false;
  bool _pageFailed = false;

  void _status({bool loading = false, Object? error}) {
    ref
        .read(workoutCatalogStatusProvider.notifier)
        .update(
          CatalogLoadState(hasMore: _hasMore, loading: loading, error: error),
        );
  }

  @override
  Stream<List<WorkoutSummary>> build() {
    final generation = ++_generation;
    _upserts.clear();
    _removed.clear();
    _mutationVersions.clear();
    _refreshing = null;
    _pages = null;
    _nextPage = null;
    _hasMore = false;
    _pageFailed = false;
    final complete = Completer<void>();
    _loading = complete.future;
    final userFuture = ref.watch(authStateProvider.future);
    final loaderFuture = ref.watch(loadWorkoutsProvider.future);
    final output = StreamController<List<WorkoutSummary>>();
    StreamSubscription<List<WorkoutSummary>>? subscription;
    var disposed = false;
    StreamIterator<WorkoutCatalogPage>? catalogPages;

    void finish() {
      if (!complete.isCompleted) complete.complete();
      unawaited(output.close());
    }

    // Drive fetches independently of Riverpod's output stream, which may pause
    // while hidden. The paged source advances only on explicit demand; legacy
    // repositories still finish their stream for existing offline consumers.
    output.onListen = () async {
      try {
        final user = await userFuture;
        if (disposed) return;
        if (user == null) {
          _status();
          output.add(const []);
          finish();
          return;
        }
        final loader = await loaderFuture;
        if (disposed) return;
        _status();
        if (loader.supportsPaging) {
          catalogPages = StreamIterator(loader.pages(requireServer: true));
          _pages = catalogPages;
          _hasMore = true;
          try {
            await _readPage(generation, (items) => output.add(_merge(items)));
          } finally {
            if (!complete.isCompleted) complete.complete();
          }
          return;
        }
        subscription = loader.watch().listen(
          (items) => output.add(_merge(items)),
          onError: (Object error, StackTrace stack) =>
              output.addError(error, stack),
          onDone: finish,
        );
      } catch (error, stack) {
        if (disposed) return;
        if (!state.hasValue) output.addError(error, stack);
        finish();
      }
    };
    ref.onDispose(() {
      disposed = true;
      if (_generation == generation) ++_generation;
      unawaited(subscription?.cancel());
      unawaited(catalogPages?.cancel());
      if (_generation == generation + 1) unawaited(_pages?.cancel());
      finish();
    });
    return output.stream;
  }

  // A scheduled start must not mistake the first page for the complete catalog.
  Future<List<WorkoutSummary>> loadComplete() async {
    final generation = _generation;
    try {
      await future;
      await _loading;
    } catch (_) {
      if (!ref.mounted || generation != _generation) return const [];
      await refresh();
    }
    while (ref.mounted && generation == _generation && _hasMore) {
      if (_pageFailed) {
        await refresh();
      } else {
        await loadMore();
      }
    }
    if (!ref.mounted || generation != _generation) return const [];
    return state.requireValue;
  }

  Future<void> loadMore() {
    if (_refreshing != null) return _refreshing!;
    final generation = _generation;
    return _nextPage ??=
        () async {
          // Cached rows can be visible while the first server page is still in
          // flight. Never advance a StreamIterator twice at the same time.
          await _loading;
          if (!ref.mounted || generation != _generation) return;
          await _readPage(generation, (items) {
            state = AsyncData(_merge(items));
          });
        }().whenComplete(() {
          if (generation == _generation) _nextPage = null;
        });
  }

  Future<void> _readPage(
    int generation,
    void Function(List<WorkoutSummary>) emit,
  ) async {
    final pages = _pages;
    if (pages == null || !_hasMore || _pageFailed) return;
    _status(loading: true);
    try {
      while (await pages.moveNext()) {
        if (!ref.mounted || generation != _generation) return;
        final page = pages.current;
        emit(page.items);
        if (page.cached) continue;
        _hasMore = !page.complete;
        if (!_hasMore) unawaited(pages.cancel());
        return;
      }
      if (ref.mounted && generation == _generation) _hasMore = false;
    } catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      _pageFailed = true;
      _status(error: error);
      Error.throwWithStackTrace(error, stack);
    } finally {
      if (ref.mounted && generation == _generation && !_pageFailed) _status();
    }
  }

  /// Keep the usable list mounted until a complete server refresh succeeds.
  /// Merge edits made during the request and discard responses for old accounts.
  Future<void> refresh() {
    final generation = _generation;
    return _refreshing ??= _refresh(generation).whenComplete(() {
      if (generation == _generation) _refreshing = null;
    });
  }

  Future<void> _refresh(int generation) async {
    try {
      await future;
      await _loading;
      await _nextPage;
    } catch (_) {
      // Initial loading can fail too; refresh is also the retry action.
    }
    if (!ref.mounted || generation != _generation) return;
    final baseline = _writeVersion;
    try {
      final loader = await ref.read(loadWorkoutsProvider.future);
      List<WorkoutSummary> items;
      if (loader.supportsPaging) {
        final pages = StreamIterator(loader.pages(requireServer: true));
        final count = state.value?.length ?? 0;
        final completeCatalog = !_hasMore && !_pageFailed;
        var loaded = const <WorkoutSummary>[];
        var hasMore = true;
        _status(loading: true);
        try {
          while (true) {
            if (!await pages.moveNext()) {
              hasMore = false;
              break;
            }
            if (!ref.mounted || generation != _generation) {
              await pages.cancel();
              return;
            }
            final page = pages.current;
            if (page.cached) continue;
            loaded = page.items;
            hasMore = !page.complete;
            if (!hasMore || (!completeCatalog && loaded.length >= count)) break;
          }
        } catch (_) {
          await pages.cancel();
          rethrow;
        }
        if (!ref.mounted || generation != _generation) {
          await pages.cancel();
          return;
        }
        unawaited(_pages?.cancel());
        _pages = pages;
        _hasMore = hasMore;
        _pageFailed = false;
        if (!hasMore) unawaited(pages.cancel());
        _status();
        items = loaded;
      } else {
        items = await loader.watch(requireServer: true).last;
      }
      if (!ref.mounted || generation != _generation) return;
      final stale = _mutationVersions.entries
          .where((entry) => entry.value <= baseline)
          .map((entry) => entry.key)
          .toList();
      for (final id in stale) {
        _upserts.remove(id);
        _removed.remove(id);
        _mutationVersions.remove(id);
      }
      state = AsyncData(_merge(items));
    } catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      _status(error: error);
      if (!state.hasValue) state = AsyncError(error, stack);
      Error.throwWithStackTrace(error, stack);
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
    _mutationVersions[workout.id] = ++_writeVersion;
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
    _mutationVersions[workoutId] = ++_writeVersion;
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
