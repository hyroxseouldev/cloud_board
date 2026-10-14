import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_pairing_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_pairing_repository.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_preparation_repository.dart';
import 'package:cloud_board/src/app/feature/operations/data/repositories/store_operations_repository_impl.dart';
import 'package:cloud_board/src/app/feature/operations/domain/repositories/store_operations_repository.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_preferences_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_preferences_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';

import 'dart:async';

import 'package:cloud_board/src/app/feature/playback/domain/repositories/playback_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/usecases/playback_actions.dart';

class _Playback extends PlaybackActions {
  _Playback() : super(_UnusedRepository());
  int checks = 0;
  Future<bool> Function() response = () async => false;
  @override
  Future<bool> hasRunningSession() {
    checks++;
    return response();
  }
}

class _UnusedRepository implements PlaybackRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final loading in [false, true]) {
    test(
      'does not query playback before owner is ready (loading=$loading)',
      () async {
        final playback = _Playback()
          ..response = () async => throw StateError('연결된 매장을 찾을 수 없습니다.');
        final pending = Completer<String?>();
        final container = ProviderContainer(
          overrides: [
            accountOwnerIdProvider.overrideWith(
              (ref) => loading ? pending.future.asStream() : Stream.value(null),
            ),
            playbackActionsProvider.overrideWithValue(playback),
          ],
        );
        addTearDown(container.dispose);
        container.listen(accountOwnerIdProvider, (_, _) {});
        await container.pump();
        if (!loading) await container.read(accountOwnerIdProvider.future);
        await container
            .read(scheduleRunnerControllerProvider.notifier)
            .runDue();
        expect(playback.checks, 0);
      },
    );
  }
  test(
    'no eligible schedules means zero playback reads across repeated ticks',
    () async {
      final playback = _Playback()
        ..response = () async => throw StateError('must not read');
      final container = ProviderContainer(
        overrides: [
          accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
          workoutSchedulesProvider.overrideWith((ref) => Stream.value([])),
          playbackActionsProvider.overrideWithValue(playback),
        ],
      );
      addTearDown(container.dispose);
      container.listen(accountOwnerIdProvider, (_, _) {});
      container.listen(workoutSchedulesProvider, (_, _) {});
      await container.read(accountOwnerIdProvider.future);
      await container.read(workoutSchedulesProvider.future);
      final runner = container.read(scheduleRunnerControllerProvider.notifier);
      for (var i = 0; i < 180; i++) {
        await runner.runDue();
      }
      expect(playback.checks, 0);
      expect(
        container.read(scheduleRunnerControllerProvider).hasError,
        isFalse,
      );
    },
  );
  test(
    'network failure is caught, concurrent ticks skip, and next tick retries',
    () async {
      final pending = Completer<bool>();
      final playback = _Playback()..response = () => pending.future;
      final container = ProviderContainer(
        overrides: [
          accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
          playbackActionsProvider.overrideWithValue(playback),
          workoutSchedulesProvider.overrideWith(
            (ref) => Stream.value([
              WorkoutSchedule(
                id: 'due',
                workoutId: 'w',
                workoutName: 'w',
                enabled: true,
                createdAtMs: 0,
                lastOccurrenceKey: null,
                targetDeviceIds: [],
                weekdays: [DateTime.now().weekday],
                hour: DateTime.now().hour,
                minute: DateTime.now().minute,
              ),
            ]),
          ),
          displayDevicesProvider.overrideWith(
            (ref) => Stream.error(StateError('fixture stop')),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(accountOwnerIdProvider, (_, _) {});
      await container.pump();
      await container.read(accountOwnerIdProvider.future);
      container.listen(workoutSchedulesProvider, (_, _) {});
      await container.pump();
      final runner = container.read(scheduleRunnerControllerProvider.notifier);
      final first = runner.runDue();
      await runner.runDue();
      await Future<void>.delayed(Duration.zero);
      expect(playback.checks, 1);
      pending.completeError(StateError('network down'));
      await first;
      expect(container.read(scheduleRunnerControllerProvider).hasError, isTrue);
      playback.response = () async => true;
      await runner.runDue();
      expect(playback.checks, 2);
      expect(
        container.read(scheduleRunnerControllerProvider).hasError,
        isFalse,
      );
    },
  );
  test(
    'account A→B→A while schedules load cancels without reading playback',
    () async {
      final schedulesGate = Completer<void>();
      final h = await _ScheduleHarness.create(schedulesGate: schedulesGate);
      addTearDown(h.dispose);
      final starting = h.runner.runDue();
      await h.container.pump();
      expect(h.container.exists(playbackActionsProvider), isFalse);
      h.owners.add('other');
      await h.container.pump();
      h.owners.add('owner');
      await h.container.pump();
      schedulesGate.complete();
      await starting;
      expect(h.playback.starts, 0);
      expect(h.operations.claims, 0);
      expect(h.container.exists(playbackActionsProvider), isFalse);
      expect(
        h.container.read(scheduleRunnerControllerProvider).isLoading,
        isFalse,
      );
    },
  );
  for (final delayed in ['session-query', 'preferences']) {
    test(
      'scheduled start retains real generated actions through delayed $delayed',
      () async {
        final h = await _ScheduleHarness.create();
        addTearDown(h.dispose);
        final gate = Completer<void>();
        if (delayed == 'session-query') h.playback.checkGate = gate;
        if (delayed == 'preferences') h.preferences.gate = gate;
        final starting = h.runner.runDue();
        await h.container.pump();
        await h.container.pump();
        expect(h.container.exists(playbackActionsProvider), isTrue);
        expect(h.playback.starts, 0);
        await h.runner
            .runDue(); // concurrent tick must not create a second claim
        gate.complete();
        await starting;
        expect(h.playback.starts, 1);
        expect(h.playback.scheduled, isTrue);
        expect(h.playback.scheduledAtMs, isNotNull);
        expect(h.operations.claims, 1);
        expect(
          h.container.read(scheduleRunnerControllerProvider).hasError,
          isFalse,
        );
        await h.container.pump();
        await h.container.pump();
        expect(h.container.exists(playbackActionsProvider), isFalse);
      },
    );
  }
  for (final boundary in ['preferences', 'repository']) {
    for (final change in ['owner', 'actions', 'runner']) {
      test(
        'scheduled $change invalidation at $boundary cancels before commit',
        () async {
          final h = await _ScheduleHarness.create();
          addTearDown(h.dispose);
          final gate = Completer<void>();
          if (boundary == 'preferences') h.preferences.gate = gate;
          if (boundary == 'repository') h.playback.startGate = gate;
          final starting = h.runner.runDue();
          if (boundary == 'repository') await h.playback.entered.future;
          await h.container.pump();
          if (change == 'owner') {
            h.owners.add('other');
            await h.container.pump();
            // Even a quick A→B→A switch must cancel the old asynchronous start.
            h.owners.add('owner');
          }
          if (change == 'actions') {
            h.container.invalidate(playbackActionsProvider);
          }
          if (change == 'runner') {
            h.container.invalidate(scheduleRunnerControllerProvider);
          }
          await h.container.pump();
          gate.complete();
          await starting;
          expect(h.playback.starts, 0);
          await h.container.pump();
          await h.container.pump();
          expect(h.container.exists(playbackActionsProvider), isFalse);
          expect(
            h.container.read(scheduleRunnerControllerProvider).isLoading,
            isFalse,
          );
        },
      );
    }
  }
  test('scheduled start preserves modern TV preparation and occurrence claim checks', () async {
    final h = await _ScheduleHarness.create();
    addTearDown(h.dispose);
    h.devices.modern = true;
    await h.runner.runDue();
    expect(h.operations.claims, 1);
    expect(
      h.playback.starts,
      0,
    ); // no preparation proof: never bypass readiness
    expect(h.container.read(scheduleRunnerControllerProvider).hasError, isTrue);
    await h.container.pump();
    expect(h.container.exists(playbackActionsProvider), isFalse);
    h.devices.modern = false;
    await h.runner.runDue(); // same occurrence is already claimed
    expect(h.operations.claims, 2);
    expect(h.playback.starts, 0);
  });
}

final _scheduledWorkout =
    Workout.empty(
      'scheduled-workout',
      const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
    ).copyWith(
      countdownSeconds: 0,
      modules: [
        WorkoutModule.empty('module')
            .copyWith(workSeconds: 60, restSeconds: 0, sets: 1),
      ],
    );

// Keep the generated actions/preferences/preparation providers and autoDispose
// behavior real. Only platform repositories and external streams are replaced.
class _ScheduleHarness {
  final owners = StreamController<String?>.broadcast(sync: true);
  final preferences = _ScheduledPreferences();
  final playback = _ScheduledPlayback();
  final operations = _ScheduledOperations();
  final devices = _ScheduledDevices();
  late final ProviderContainer container;
  ScheduleRunnerController get runner =>
      container.read(scheduleRunnerControllerProvider.notifier);
  static Future<_ScheduleHarness> create({
    Completer<void>? schedulesGate,
  }) async {
    final h = _ScheduleHarness();
    final now = DateTime.now();
    final schedule = WorkoutSchedule(
      id: 'schedule-due',
      workoutId: _scheduledWorkout.id,
      workoutName: '예약 수업',
      enabled: true,
      createdAtMs: 0,
      lastOccurrenceKey: null,
      targetDeviceIds: ['scheduled-tv'],
      weekdays: [now.weekday],
      hour: now.hour,
      minute: now.minute,
    );
    h.container = ProviderContainer(
      overrides: [
        accountOwnerIdProvider.overrideWith((_) async* {
          yield 'owner';
          yield* h.owners.stream;
        }),
        workoutSchedulesProvider.overrideWith((_) async* {
          await schedulesGate?.future;
          yield [schedule];
        }),
        workoutDetailProvider(_scheduledWorkout.id)
            .overrideWith(_ScheduledWorkoutDetail.new),
        displayDevicesProvider.overrideWith((_) => h.devices.watchDevices()),
        deviceIdProvider.overrideWith((_) async => 'controller'),
        playbackRepositoryProvider.overrideWith((_) => h.playback),
        workoutPreferencesRepositoryProvider.overrideWith((_) => h.preferences),
        storeOperationsRepositoryProvider.overrideWith((_) => h.operations),
        devicePairingRepositoryProvider.overrideWith((_) => h.devices),
        displayPreparationRepositoryProvider.overrideWith(
          (_) => _UnusedPreparation(),
        ),
      ],
    );
    h.container.listen(accountOwnerIdProvider, (_, _) {});
    // DeviceModeHomeScreen keeps schedules observed while running due work.
    h.container.listen(workoutSchedulesProvider, (_, _) {});
    // The controller home also renders WorkoutListScreen display status.
    h.container.listen(displayDevicesProvider, (_, _) {});
    await h.container.read(accountOwnerIdProvider.future);
    if (schedulesGate == null) {
      await h.container.read(workoutSchedulesProvider.future);
    }
    return h;
  }

  Future<void> dispose() async {
    container.dispose();
    await owners.close();
  }
}

class _ScheduledPreferences extends Fake
    implements WorkoutPreferencesRepository {
  Completer<void>? gate;
  @override
  Future<WorkoutPreferences?> load(String ownerId, {bool fresh = false}) async {
    await gate?.future;
    return null;
  }
}

class _ScheduledOperations extends Fake implements StoreOperationsRepository {
  int claims = 0;
  final claimed = <String>{};
  @override
  Future<bool> claimOccurrence(String scheduleId, String occurrenceKey) async {
    claims++;
    return claimed.add('$scheduleId/$occurrenceKey');
  }
}

class _UnusedPreparation extends Fake implements DisplayPreparationRepository {}

class _ScheduledDevices extends Fake implements DevicePairingRepository {
  bool modern = false;
  @override
  Stream<List<DisplayDevice>> watchDevices() => Stream.value([
    DisplayDevice(
      id: 'scheduled-tv',
      name: 'TV',
      zoneId: 'main',
      zoneName: '',
      online: true,
      lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
      currentSessionId: null,
      acknowledgedRevision: 0,
      paired: true,
      playbackProtocol: 5,
      preparationProtocol: modern ? 1 : 0,
    ),
  ]);
}

class _ScheduledPlayback extends Fake implements PlaybackRepository {
  int starts = 0;
  bool? scheduled;
  int? scheduledAtMs;
  Completer<void>? checkGate, startGate;
  final entered = Completer<void>();
  @override
  Future<bool> hasRunningSession() async {
    await checkGate?.future;
    return starts > 0;
  }

  @override
  Future<PlaybackSession> start({
    required Workout workout,
    required List<String> targetDeviceIds,
    required int stepIndex,
    required int durationMs,
    required String deviceId,
    bool scheduled = false,
    bool briefing = false,
    int? scheduledAtMs,
    void Function()? ensureCurrent,
  }) async {
    if (!entered.isCompleted) entered.complete();
    await startGate?.future;
    ensureCurrent?.call();
    starts++;
    this.scheduled = scheduled;
    this.scheduledAtMs = scheduledAtMs;
    return PlaybackSessionModel.fromWorkout(
      id: 'scheduled-session',
      ownerId: workout.ownerId,
      zoneId: 'main',
      targetDeviceIds: targetDeviceIds,
      workout: workout,
      stepIndex: stepIndex,
      durationMs: durationMs,
      deviceId: deviceId,
    ).toEntity();
  }
}

class _ScheduledWorkoutDetail extends WorkoutDetail {
  @override
  Future<Workout?> build(String id) async => _scheduledWorkout;
}
