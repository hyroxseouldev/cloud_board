import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_recovery_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_recovery_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_write_conflict.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_recovery_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final workout =
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'a', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      name: 'Recovered class',
      folder: 'Monday',
      countdownImageSource: 'data:image/png;base64,AQID',
      modules: [
        WorkoutModule.empty('m').copyWith(
          imageSource: 'data:image/png;base64,BQID',
          text: 'unsaved text',
          workSeconds: 77,
        ),
      ],
    );

void main() {
  late _Preferences preferences;
  late _Assets assets;
  LocalWorkoutRecoveryRepository reopen() =>
      LocalWorkoutRecoveryRepository(preferences: preferences, assets: assets);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = _Preferences();
    assets = _Assets();
  });

  test('whole draft and local images survive restart, scoped to account and editor', () async {
    await reopen().save(
      'a',
      'new',
      WorkoutRecoveryDraft(workout: workout, isNew: true),
    );
    final recovered = await reopen().load('a', 'new');
    expect(recovered!.workout, workout);
    expect(recovered.isNew, isTrue);
    expect(await reopen().load('b', 'new'), isNull);
    expect(await reopen().load('a', 'other'), isNull);
    expect(
      preferences.values.values.every((value) => value.length == 64),
      isTrue,
    );
    await expectLater(
      reopen().save(
        'b',
        'new',
        WorkoutRecoveryDraft(workout: workout, isNew: true),
      ),
      throwsStateError,
    );
  });

  test(
    'failed metadata replacement preserves previous complete snapshot',
    () async {
      final repository = reopen();
      await repository.save(
        'a',
        'w',
        WorkoutRecoveryDraft(workout: workout, isNew: false),
      );
      preferences.fail = true;
      await expectLater(
        repository.save(
          'a',
          'w',
          WorkoutRecoveryDraft(
            workout: workout.copyWith(name: 'Changed'),
            isNew: false,
          ),
        ),
        throwsStateError,
      );
      preferences.fail = false;
      expect((await reopen().load('a', 'w'))!.workout, workout);
      await repository.save(
        'a',
        'w',
        WorkoutRecoveryDraft(
          workout: workout.copyWith(name: 'Changed'),
          isNew: false,
        ),
      );
      expect((await reopen().load('a', 'w'))!.workout.name, 'Changed');
      expect(
        assets.values.length,
        3,
      ); // One manifest and two reused image assets.
    },
  );

  test(
    'clearing waits for pending writes and cannot resurrect a discarded draft',
    () async {
      final repository = reopen();
      final gate = Completer<void>();
      assets.gate = gate.future;
      final saving = repository.save(
        'a',
        'new',
        WorkoutRecoveryDraft(workout: workout, isNew: true),
      );
      final clearing = repository.clear('a', 'new');
      gate.complete();
      await Future.wait([saving, clearing]);
      expect(await reopen().load('a', 'new'), isNull);
      expect(assets.values, isEmpty);
    },
  );

  test('controller retains snapshot after save failure and clear prevents dispose resurrection', () async {
    final repository = reopen();
    final container = ProviderContainer(
      overrides: [
        workoutRecoveryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final provider = workoutRecoveryControllerProvider('a', 'new');
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    final actions = container.read(provider.notifier)..accept();
    actions.record(workout, isNew: true);
    expect(await actions.flush(), isTrue);
    expect((await reopen().load('a', 'new'))!.workout, workout);
    await actions.clear();
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(await reopen().load('a', 'new'), isNull);
  });

  test('stale editor revision rejects concurrent changes but allows create and matching edit', () {
    final old = DateTime.utc(2026, 10, 12);
    final latest = old.add(const Duration(seconds: 1));
    expect(
      () => ensureWorkoutRevision(expected: old, current: latest),
      throwsA(isA<WorkoutWriteConflict>()),
    );
    ensureWorkoutRevision(expected: old, current: old);
    ensureWorkoutRevision(expected: old, current: null);
  });
}

class _Preferences extends SharedPreferencesAsync {
  final values = <String, String>{};
  final _failure = [false];
  bool get fail => _failure.single;
  set fail(bool value) => _failure[0] = value;
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    if (fail) throw StateError('disk full');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class _Assets implements DraftAssetStore {
  final values = <String, Uint8List>{};
  Future<void>? gate;
  @override
  Future<bool> exists(String draft, String asset) async =>
      values.containsKey('$draft/$asset');
  @override
  Future<Uint8List?> read(String draft, String asset) async =>
      values['$draft/$asset'];
  @override
  Future<void> write(String draft, String asset, Uint8List bytes) async {
    await gate;
    values['$draft/$asset'] = bytes;
  }

  @override
  Future<void> retain(String draft, Set<String> assets) async {
    values.removeWhere(
      (key, _) =>
          key.startsWith('$draft/') &&
          !assets.contains(key.substring(draft.length + 1)),
    );
  }
}
