import 'dart:async';

import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/feature/operations/data/operation_event_writer.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/operation_event_recorder.dart';

import 'package:flutter/material.dart' hide NavigationMode;
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';

import 'support/main_navigation_fixture.dart';
import 'support/workout_recovery_fixture.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_pairing_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_pairing_repository.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_preparation_repository.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/entitlement_controller.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';
import 'package:cloud_board/src/app/feature/playback/domain/repositories/playback_repository.dart';
import 'package:cloud_board/src/app/feature/playback/domain/usecases/playback_actions.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_preferences_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_preferences_repository.dart';

import 'support/workout_catalog_fixture.dart' show fixtureSavedSlideOrder;

// Real generated controller/actions/preferences/preparation providers. Only
// platform data repositories are replaced; autoDispose is never overridden.
final _workout =
    Workout.empty(
      'start-lifecycle',
      const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
    ).copyWith(
      name: '준비된 수업',
      countdownSeconds: 0,
      modules: [
        WorkoutModule.empty('slide')
            .copyWith(name: '워밍업', workSeconds: 180, restSeconds: 0, sets: 1),
      ],
    );
const _targets = ['tv-a', 'tv-b', 'tv-c'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'start receipt survives a completed baseline until the new session stream arrives',
    (tester) async {
      final h = await _Harness.create(captureReceipts: true);
      addTearDown(h.dispose);
      final previous = PlaybackSessionModel.fromWorkout(
        id: 'previous-completed-session',
        ownerId: _workout.ownerId,
        zoneId: 'main',
        targetDeviceIds: _targets,
        workout: _workout,
        stepIndex: 0,
        durationMs: 1000,
        deviceId: 'controller',
      ).toEntity().copyWith(status: PlaybackStatus.completed, remainingMs: 0);
      h.repository.session = previous;
      h.repository.publishStartToStream = false;
      h.devices.sessionId = previous.id;
      h.container.listen(activePlaybackSessionProvider, (_, _) {});
      h.container.listen(displayDevicesProvider, (_, _) {});
      await h.container.read(activePlaybackSessionProvider.future);
      await h.container.read(displayDevicesProvider.future);
      await tester.pump();

      // The server confirms the new start while the subscription still holds
      // the previous completed class and its old display receipts.
      expect(await h.start(), 'session-1');
      await tester.pump();
      expect(h.repository.starts, 1);
      expect(h.repository.session?.status, PlaybackStatus.playing);
      expect(
        h.container.read(activePlaybackSessionProvider).value?.id,
        previous.id,
      );
      expect(
        h.container.read(activePlaybackSessionProvider).value?.status,
        PlaybackStatus.completed,
      );
      expect(h.receiptEvents, isEmpty);

      // Publish the new session first. The old display receipts must neither
      // satisfy nor cancel the new start's receipt observer.
      h.repository.changes.add(h.repository.session);
      await tester.pump();
      expect(
        h.container.read(activePlaybackSessionProvider).value?.id,
        'session-1',
      );
      expect(h.receiptEvents, isEmpty);

      // The fixture now emits the exact new session/revision for all targets.
      // Invalidation only resubscribes this fake device transport.
      h.container.invalidate(displayDevicesProvider);
      await h.container.read(displayDevicesProvider.future);
      await tester.pump();
      await tester.pump();
      expect(h.receiptEvents, hasLength(_targets.length));
      expect(
        h.receiptEvents.every(
          (event) =>
              event.type == 'command_received' &&
              event.phase == 'tv_receipt' &&
              event.sessionId == 'session-1',
        ),
        isTrue,
      );
      expect(
        h.receiptEvents.map((event) => event.deviceId),
        unorderedEquals(_targets),
      );
      await tester.pump(const Duration(seconds: 15));
      expect(h.receiptEvents, hasLength(_targets.length));
      expect(
        h.receiptEvents.where(
          (event) => event.type == 'command_receipt_failed',
        ),
        isEmpty,
      );
    },
  );
  for (final entry in ['list', 'editor']) {
    testWidgets(
      '$entry starts one playing session after all three TV receipts',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = await _Harness.create();
        final defaults = WorkoutPreferences.fromWorkout(_workout);
        h.preferences.value = defaults.copyWith(
          countdown: defaults.countdown.copyWith(
            appearance: defaults.countdown.appearance.copyWith(
              numberScale: 0.5,
            ),
          ),
        );
        addTearDown(h.dispose);
        Uri? destination;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => entry == 'list'
                  ? const WorkoutListScreen()
                  : WorkoutEditorScreen(workoutId: _workout.id),
            ),
            GoRoute(
              path: '/player/:id',
              builder: (_, state) {
                destination = state.uri;
                return const Scaffold(body: Text('진행 중 수업'));
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: MaterialApp.router(
              theme: XonTheme.light,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final play = entry == 'list'
            ? find.byTooltip('재생').first
            : find.byKey(const ValueKey('workout-play-button'));
        await tester.ensureVisible(play);
        await tester.tap(play);
        await tester.pumpAndSettle();
        expect(find.text('수업 준비'), findsOneWidget);
        expect(h.preparation.value.targetDeviceIds, unorderedEquals(_targets));
        expect(h.preparation.values.length, 3);
        final start = find.widgetWithText(FilledButton, '수업 시작');
        expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
        h.preferences.gate = Completer<void>();
        await tester.tap(start);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(h.repository.starts, 0);
        h.preferences.gate!.complete();
        await tester.pumpAndSettle();
        expect(h.repository.starts, 1);
        expect(h.repository.session?.status, PlaybackStatus.playing);
        expect(
          h.repository.session?.workout.countdownAppearance.numberScale,
          0.5,
        );
        expect(
          h.repository.session?.targetDeviceIds,
          unorderedEquals(_targets),
        );
        expect(destination?.queryParameters['session'], 'session-1');
        expect(find.text('진행 중 수업'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await h.dispose();
      },
    );
  }
  for (final delayed in ['preferences', 'device']) {
    test(
      'real generated start survives delayed $delayed across disposal frames',
      () async {
        final h = await _Harness.create();
        addTearDown(h.dispose);
        final gate = Completer<void>();
        if (delayed == 'preferences') h.preferences.gate = gate;
        if (delayed == 'device') h.deviceGate = gate;
        final starting = h.start();
        await h.container.pump();
        await h.container.pump();
        expect(h.container.exists(playbackActionsProvider), isTrue);
        expect(h.repository.starts, 0);
        gate.complete();
        expect(await starting, 'session-1');
        expect(h.repository.session?.status, PlaybackStatus.playing);
        expect(h.repository.session?.targetDeviceIds, _targets);
        expect(h.repository.starts, 1);
        expect(
          h.container.read(playbackActionControllerProvider).isLoading,
          isFalse,
        );
        await h.container.pump();
        await h.container.pump();
        expect(h.container.exists(playbackActionsProvider), isFalse);
      },
    );
  }
  test('duplicate taps create exactly one session and route detachment keeps submitted work', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    h.preferences.gate = Completer<void>();
    final screen = h.container.listen(
      playbackActionControllerProvider,
      (_, _) {},
    );
    final starting = h.start();
    await h.container.pump();
    expect(await h.start(), isNull);
    screen.close();
    await h.container.pump();
    h.preferences.gate!.complete();
    expect(await starting, 'session-1');
    expect(h.repository.starts, 1);
    final returnedScreen = h.container.listen(
      playbackActionControllerProvider,
      (_, _) {},
    );
    expect(h.container.read(playbackActionControllerProvider).hasValue, isTrue);
    returnedScreen.close();
  });
  for (final change in ['account', 'actions', 'controller']) {
    test(
      '$change change cancels pending start without an old-account write',
      () async {
        final h = await _Harness.create();
        addTearDown(h.dispose);
        h.preferences.gate = Completer<void>();
        final starting = h.start();
        await h.container.pump();
        if (change == 'account') h.users.add(_User('another-owner'));
        if (change == 'actions') {
          h.container.invalidate(playbackActionsProvider);
        }
        if (change == 'controller') {
          h.container.invalidate(playbackActionControllerProvider);
        }
        await h.container.pump();
        h.preferences.gate!.complete();
        expect(await starting, isNull);
        expect(h.repository.starts, 0);
        expect(
          h.container.read(playbackActionControllerProvider).isLoading,
          isFalse,
        );
        await h.container.pump();
        expect(h.container.exists(playbackActionsProvider), isFalse);
      },
    );
  }
  for (final change in ['actions', 'controller']) {
    test(
      '$change invalidation during repository start cancels before commit',
      () async {
        final h = await _Harness.create();
        addTearDown(h.dispose);
        h.repository.startGate = Completer<void>();
        final starting = h.start();
        await h.repository.startEntered.future;
        if (change == 'actions') {
          h.container.invalidate(playbackActionsProvider);
        } else {
          h.container.invalidate(playbackActionControllerProvider);
        }
        await h.container.pump();
        h.repository.startGate!.complete();
        expect(await starting, isNull);
        expect(h.repository.starts, 0);
        expect(h.repository.session, isNull);
        expect(
          h.container.read(playbackActionControllerProvider).isLoading,
          isFalse,
        );
      },
    );
  }
  test('device lookup account change is caught before preferences or session writes', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    h.deviceGate = Completer<void>();
    final starting = h.start();
    await h.container.pump();
    h.users.add(_User('other'));
    await h.container.pump();
    h.deviceGate!.complete();
    expect(await starting, isNull);
    expect(h.preferences.reads, 0);
    expect(h.repository.starts, 0);
  });
  test(
    'preferences failure clears loading, releases listeners and can retry',
    () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      h.preferences.fail = true;
      expect(await h.start(), isNull);
      expect(
        h.container.read(playbackActionControllerProvider).hasError,
        isTrue,
      );
      final error = h.container.read(playbackActionControllerProvider).error;
      final event = h.container.read(errorReporterProvider).eventFor(error);
      expect(event?.error, same(error));
      expect(event?.context['startStage'], 'preferences');
      expect(event?.context['operationId'], isNotEmpty);
      expect(event?.context['action'], 'playback.start.preferences');
      await h.container.pump();
      expect(h.container.exists(playbackActionsProvider), isFalse);
      h.preferences.fail = false;
      expect(await h.start(), 'session-1');
      expect(h.repository.starts, 1);
    },
  );
  for (final invalid in [
    'unready',
    'stale',
    'expired',
    'changed-content',
    'permission',
  ]) {
    test(
      '$invalid preparation or permission never creates a new session',
      () async {
        final h = await _Harness.create();
        addTearDown(h.dispose);
        if (invalid == 'unready') h.preparation.values.remove('tv-c');
        if (invalid == 'stale') {
          final receipt = h.preparation.values['tv-c']!;
          h.preparation.values['tv-c'] = DisplayPreparationReceipt(
            sessionId: receipt.sessionId,
            revision: 0,
            manifestHash: receipt.manifestHash,
            status: receipt.status,
            checkedAtMs: receipt.checkedAtMs,
            imageCount: receipt.imageCount,
            audioReady: receipt.audioReady,
          );
        }
        if (invalid == 'expired') {
          final candidate = h.preparation.value;
          h.preparation.value = DisplayPreparation(
            sessionId: candidate.sessionId,
            revision: candidate.revision,
            manifestHash: candidate.manifestHash,
            workoutId: candidate.workoutId,
            expiresAtMs: 1,
            targetDeviceIds: candidate.targetDeviceIds,
            images: candidate.images,
            sounds: candidate.sounds,
            requiredProtocol: candidate.requiredProtocol,
          );
        }
        if (invalid == 'changed-content') {
          h.proof = DisplayPreparationProof(
            manifestHash: 'changed',
            sessionId: h.proof.sessionId,
            revision: h.proof.revision,
          );
        }
        if (invalid == 'permission') {
          h.repository.fail = const PlaybackFailure(
            'permission-denied',
            '권한 확인 실패',
          );
        }
        expect(await h.start(), isNull);
        expect(h.repository.starts, 0);
        expect(
          h.container.read(playbackActionControllerProvider).hasError,
          isTrue,
        );
      },
    );
  }
  test(
    'same prepared candidates can retry after a missing receipt arrives',
    () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      final missing = h.preparation.values.remove('tv-c')!;
      expect(await h.start(), isNull);
      h.preparation.values['tv-c'] = missing;
      expect(await h.start(), 'session-1');
      expect(h.repository.starts, 1);
    },
  );
}

class _Harness {
  final users = StreamController<User?>.broadcast(sync: true);
  final preferences = _Preferences();
  final devices = _Devices();
  final receiptEvents = <OperationEvent>[];
  late final _Preparation preparation;
  late final _Playback repository;
  late final ProviderContainer container;
  late DisplayPreparationProof proof;
  Completer<void>? deviceGate;
  static Future<_Harness> create({bool captureReceipts = false}) async {
    final h = _Harness();
    h.preparation = _Preparation();
    h.repository = _Playback(h.devices);
    h.proof = DisplayPreparationProof(
      manifestHash: h.preparation.value.manifestHash,
      sessionId: h.preparation.value.sessionId,
      revision: h.preparation.value.revision,
    );
    h.container = ProviderContainer(
      overrides: [
        fixtureSavedSlideOrder,
        memoryWorkoutRecovery,
        if (captureReceipts)
          accountOwnerIdProvider.overrideWith((_) => Stream.value('owner')),
        if (captureReceipts)
          operationEventWriterProvider.overrideWith((ref) {
            final writer = OperationEventWriter(
              (event) async => h.receiptEvents.add(event),
            );
            ref.onDispose(writer.dispose);
            return writer;
          }),
        authStateProvider.overrideWith(
          (_) => Stream.value(
            const AuthUser(
              id: 'owner',
              email: 'coach@example.invalid',
              displayName: '코치',
              photoUrl: null,
            ),
          ),
        ),
        deviceModeControllerProvider.overrideWith(NavigationMode.new),
        displayDevicesProvider.overrideWith((_) => h.devices.watchDevices()),
        slideEditorRepositoryProvider.overrideWithValue(
          LocalSlideEditorRepository(SlideEditorLocalDataSource()),
        ),
        workoutRepositoryProvider.overrideWith(
          (_) async => NavigationWorkoutRepository([_workout]),
        ),
        firebaseAccountUserProvider.overrideWith((_) async* {
          yield _User('owner');
          yield* h.users.stream;
        }),
        storeEntitlementProvider.overrideWith(
          (_) => Stream.value(
            StoreEntitlement(
              ownerId: 'owner',
              serverConfirmed: true,
              canStartClass: true,
              validUntilMs: DateTime.now().millisecondsSinceEpoch + 600000,
            ),
          ),
        ),
        deviceIdProvider.overrideWith((_) async {
          await h.deviceGate?.future;
          return 'controller';
        }),
        playbackRepositoryProvider.overrideWith((_) => h.repository),
        workoutPreferencesRepositoryProvider.overrideWith((_) => h.preferences),
        devicePairingRepositoryProvider.overrideWith((_) => h.devices),
        displayPreparationRepositoryProvider.overrideWith((_) => h.preparation),
      ],
    );
    h.container.listen(firebaseAccountUserProvider, (_, _) {});
    h.container.listen(storeEntitlementProvider, (_, _) {});
    await h.container.read(firebaseAccountUserProvider.future);
    await h.container.read(storeEntitlementProvider.future);
    if (captureReceipts) {
      h.container.listen(accountOwnerIdProvider, (_, _) {});
      await h.container.read(accountOwnerIdProvider.future);
    }
    return h;
  }

  Future<String?> start() => container
      .read(playbackActionControllerProvider.notifier)
      .start(
        workout: _workout,
        stepIndex: 0,
        durationMs: 1000,
        targetDeviceIds: _targets,
        preparationProof: proof,
      );
  bool disposed = false;
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    container.dispose();
    await users.close();
    await repository.changes.close();
  }
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  bool get isAnonymous => false;
}

class _Preferences extends Fake implements WorkoutPreferencesRepository {
  WorkoutPreferences? value;
  Completer<void>? gate;
  bool fail = false;
  int reads = 0;
  @override
  Future<WorkoutPreferences> loadForEditing(String ownerId) async =>
      WorkoutPreferences.fromWorkout(_workout);
  @override
  Future<WorkoutPreferences?> load(String ownerId, {bool fresh = false}) async {
    reads++;
    await gate?.future;
    if (fail) throw StateError('설정 조회 실패');
    return value;
  }
}

class _Devices extends Fake implements DevicePairingRepository {
  String? sessionId;
  @override
  Stream<List<DisplayDevice>> watchDevices() => Stream.value([
    for (final id in _targets)
      DisplayDevice(
        id: id,
        name: id,
        zoneId: 'main',
        zoneName: '',
        online: true,
        lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
        currentSessionId: sessionId,
        acknowledgedRevision: 1,
        paired: true,
        playbackProtocol: 5,
        preparationProtocol: 1,
      ),
  ]);
}

class _Preparation extends Fake implements DisplayPreparationRepository {
  _Preparation() {
    value = prepareDisplayCandidate(
      _workout,
      _targets,
      sessionId: 'prepare-lifecycle',
      revision: 1,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    values = {
      for (final id in _targets)
        id: DisplayPreparationReceipt(
          sessionId: value.sessionId,
          revision: value.revision,
          manifestHash: value.manifestHash,
          status: 'ready',
          checkedAtMs: DateTime.now().millisecondsSinceEpoch,
          imageCount: 0,
          audioReady: true,
        ),
    };
  }
  late DisplayPreparation value;
  late Map<String, DisplayPreparationReceipt> values;
  @override
  Future<void> request(DisplayPreparation request) async {
    value = request;
    values = {
      for (final id in request.targetDeviceIds)
        id: DisplayPreparationReceipt(
          sessionId: request.sessionId,
          revision: request.revision,
          manifestHash: request.manifestHash,
          status: 'ready',
          checkedAtMs: DateTime.now().millisecondsSinceEpoch,
          imageCount: request.images.length,
          audioReady: true,
        ),
    };
  }

  @override
  Stream<Map<String, DisplayPreparationReceipt>> watchReceipts() =>
      Stream.value(values);
  @override
  Future<DisplayPreparation?> current() async => value;
  @override
  Future<Map<String, DisplayPreparationReceipt>> receipts() async => values;
}

class _Playback extends Fake implements PlaybackRepository {
  _Playback(this.devices);
  final _Devices devices;
  int starts = 0;
  bool publishStartToStream = true;
  Completer<void>? startGate;
  final startEntered = Completer<void>();
  Object? fail;
  PlaybackSession? session;
  final changes = StreamController<PlaybackSession?>.broadcast(sync: true);
  @override
  Stream<int> watchServerTimeOffset() => Stream.value(0);
  @override
  Stream<bool> watchConnected() => Stream.value(true);
  @override
  Stream<PlaybackSession?> watchActive() async* {
    yield session;
    yield* changes.stream;
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
    if (!startEntered.isCompleted) startEntered.complete();
    await startGate?.future;
    ensureCurrent?.call();
    if (fail != null) throw fail!;
    starts++;
    devices.sessionId = 'session-$starts';
    session = PlaybackSessionModel.fromWorkout(
      id: devices.sessionId!,
      ownerId: workout.ownerId,
      zoneId: 'main',
      targetDeviceIds: targetDeviceIds,
      workout: workout,
      stepIndex: stepIndex,
      durationMs: durationMs,
      deviceId: deviceId,
    ).toEntity();
    if (publishStartToStream) changes.add(session);
    return session!;
  }
}
