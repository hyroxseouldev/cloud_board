import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';

part 'workout_controller.g.dart';

@Riverpod(keepAlive: true)
class WorkoutController extends _$WorkoutController {
  final _upserts = <String, Workout>{};
  final _removed = <String>{};
  Future<void>? _loading;

  @override
  Stream<List<Workout>> build() async* {
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
  Future<List<Workout>> loadComplete() async {
    await future;
    await _loading;
    return state.requireValue;
  }

  List<Workout> _merge(List<Workout> items) {
    final merged = {for (final item in items) item.id: item, ..._upserts};
    for (final id in _removed) {
      merged.remove(id);
    }
    return merged.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void upsert(Workout workout) {
    _upserts[workout.id] = workout;
    _removed.remove(workout.id);
    final items = state.value;
    if (items == null) return;
    final index = items.indexWhere((item) => item.id == workout.id);
    final next = [...items];
    if (index == -1) {
      next.insert(0, workout);
    } else {
      next[index] = workout;
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

  Future<Workout?> save(Workout workout) async {
    state = const AsyncLoading();
    Workout? saved;
    state = await AsyncValue.guard(() async {
      final value = workout.copyWith(updatedAt: DateTime.now());
      saved = await (await ref.read(saveWorkoutProvider.future))(value);
      ref.read(workoutControllerProvider.notifier).upsert(saved!);
      return '워크아웃을 저장했습니다.';
    });
    return state.hasError ? null : saved;
  }

  Future<bool> delete(String workoutId) => _run(
    successMessage: '워크아웃을 삭제했습니다.',
    action: () async {
      await (await ref.read(deleteWorkoutProvider.future))(workoutId);
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
      ref.read(workoutControllerProvider.notifier).upsert(saved);
    },
  );

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
