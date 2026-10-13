import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/entities/app_release.dart';
import 'package:cloud_board/src/app/feature/app_update/presentation/controllers/app_update_controller.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/display_settings_screen.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_refresh_button.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operations_metrics.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/views/display_mode_screen.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';

class _Mode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.display;
  @override
  Future<bool> setMode(DeviceMode mode) async {
    state = AsyncData(mode);
    return true;
  }
}

class _Pair extends DevicePairingController {
  @override
  Future<DevicePairing> build() async => const DevicePairing(
    code: '123456',
    deviceId: 'tv',
    expiresAtMs: 9999999999999,
  );
}

class _PairActions implements DevicePairingActions {
  final identificationAcks = <String>[];
  @override
  Future<void> acknowledgeIdentification(String deviceId, String nonce) async {
    identificationAcks.add('$deviceId:$nonce');
  }

  @override
  Future<void> acknowledge({
    required String deviceId,
    required String sessionId,
    required int revision,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DisplayDevice device(String displayState) => DisplayDevice(
  id: 'tv',
  name: '매장 TV',
  zoneId: 'main',
  zoneName: '매장',
  online: true,
  lastSeenAtMs: 0,
  currentSessionId: null,
  acknowledgedRevision: 0,
  paired: true,
  displayState: displayState,
);
final workout =
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      countdownSeconds: 0,
      modules: [WorkoutModule.empty('m').copyWith(beep: false)],
    );
PlaybackSession running() => PlaybackSessionModel.fromWorkout(
  id: 's',
  ownerId: 'u',
  zoneId: 'main',
  targetDeviceIds: ['tv'],
  workout: workout,
  stepIndex: 0,
  durationMs: 60000,
  deviceId: 'phone',
).toEntity().copyWith(anchorServerMs: DateTime.now().millisecondsSinceEpoch);

class _RequiredTvUpdate extends AppUpdateController {
  @override
  Future<({AppRelease release, UpdateKind kind})?> build() async => (
    release: const AppRelease(
      latestBuild: 100,
      minimumBuild: 99,
      publishedBuild: 100,
      version: '1.2.0',
      storeUrl: 'https://play.google.com/store/apps/details?id=com.sunmkim.cloudboard',
      enabled: true,
      published: true,
    ),
    kind: UpdateKind.required,
  );
}

class _ControlledRecovery extends PlaybackRecoveryController {
  void update(AsyncValue<void> value) => state = value;
}

void main() {
  testWidgets(
    'TV update appears only in confirmed standby and yields to a class, recovery or connection loss',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sessions = StreamController<PlaybackSession?>.broadcast();
      final connection = StreamController<bool>.broadcast();
      final devices = StreamController<List<DisplayDevice>>.broadcast();
      final recovery = _ControlledRecovery();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            androidTvProvider.overrideWith((ref) async => true),
            appUpdateControllerProvider.overrideWith(_RequiredTvUpdate.new),
            playbackRecoveryControllerProvider.overrideWith(() => recovery),
            accountOwnerIdProvider.overrideWith((ref) => Stream.value('u')),
            deviceIdProvider.overrideWith((ref) async => 'tv'),
            deviceModeControllerProvider.overrideWith(_Mode.new),
            devicePairingControllerProvider.overrideWith(_Pair.new),
            devicePairingActionsProvider.overrideWithValue(_PairActions()),
            displayDevicesProvider.overrideWith((ref) => devices.stream),
            activePlaybackSessionProvider.overrideWith(
              (ref) => sessions.stream,
            ),
            playbackConnectionProvider.overrideWith((ref) => connection.stream),
            serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
            effectiveBrandTemplateProvider.overrideWith(
              (ref) => Stream.value(BrandTemplate.initial()),
            ),
            workoutSchedulesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: DisplayModeScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('새 버전으로 함께해요'), findsNothing);
      devices.add([device('standby')]);
      connection.add(true);
      sessions.add(null);
      await tester.pumpAndSettle();
      expect(find.text('새 버전으로 함께해요'), findsOneWidget);
      for (final status in [PlaybackStatus.playing, PlaybackStatus.paused]) {
        sessions.add(running().copyWith(status: status));
        await tester.pumpAndSettle();
        expect(find.text('새 버전으로 함께해요'), findsNothing);
      }
      sessions.add(
        running().copyWith(
          status: PlaybackStatus.completed,
          anchorServerMs: DateTime.now().millisecondsSinceEpoch - 10000,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('새 버전으로 함께해요'), findsOneWidget);
      recovery.update(const AsyncLoading());
      await tester.pumpAndSettle();
      expect(find.text('새 버전으로 함께해요'), findsNothing);
      recovery.update(
        AsyncError(StateError('offline recovery'), StackTrace.current),
      );
      await tester.pumpAndSettle();
      expect(find.text('새 버전으로 함께해요'), findsNothing);
      recovery.update(const AsyncData(null));
      await tester.pumpAndSettle();
      expect(find.text('새 버전으로 함께해요'), findsOneWidget);
      connection.add(false);
      await tester.pumpAndSettle();
      expect(find.text('새 버전으로 함께해요'), findsNothing);
      connection.add(true);
      devices.add([device('black')]);
      sessions.add(null);
      await tester.pumpAndSettle();
      expect(find.text('새 버전으로 함께해요'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await sessions.close();
      await connection.close();
      await devices.close();
    },
  );

  testWidgets(
    'brand downgrade waits for standby and cannot black out or replace active class',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sessions = StreamController<PlaybackSession?>.broadcast();
      final brands = StreamController<BrandTemplate>.broadcast();
      // An active player ticks every 100 ms and is not expected to settle.
      // Wait for the actual rendered state, with a small bounded frame budget.
      Future<void> pumpUntil(bool Function() ready, String reason) async {
        for (var frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (ready()) return;
        }
        expect(ready(), isTrue, reason: reason);
      }

      final canvasFinder = find.byType(WorkoutSlideCanvas);
      bool playerReady() =>
          canvasFinder.evaluate().length == 1 &&
          !tester.widget<WorkoutSlideCanvas>(canvasFinder).isPaused;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            androidTvProvider.overrideWith((_) async => true),
            playerClockProvider.overrideWith((_) => tester.binding.clock.now),
            accountOwnerIdProvider.overrideWith((_) => Stream.value('u')),
            deviceIdProvider.overrideWith((_) async => 'tv'),
            deviceModeControllerProvider.overrideWith(_Mode.new),
            devicePairingControllerProvider.overrideWith(_Pair.new),
            devicePairingActionsProvider.overrideWithValue(_PairActions()),
            displayDevicesProvider.overrideWith(
              (_) => Stream.value([device('auto')]),
            ),
            activePlaybackSessionProvider.overrideWith((_) => sessions.stream),
            playbackConnectionProvider.overrideWith((_) => Stream.value(true)),
            serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
            effectiveBrandTemplateProvider.overrideWith((_) => brands.stream),
            workoutSchedulesProvider.overrideWith((_) => Stream.value([])),
          ],
          child: const MaterialApp(home: DisplayModeScreen()),
        ),
      );
      await tester.pump();
      final current = running().copyWith(
        anchorServerMs: tester.binding.clock.now().millisecondsSinceEpoch,
      );
      sessions.add(current);
      brands.add(
        BrandTemplate.initial().copyWith(
          storeName: 'Paid center',
          showCloudBoardLogo: false,
        ),
      );
      await pumpUntil(playerReady, 'The running slide must render');
      expect(find.byType(WorkoutPlayerScreen), findsOneWidget);
      final player = tester.element(find.byType(WorkoutPlayerScreen));
      final container = ProviderScope.containerOf(player);
      final timer = playerControllerProvider(
        current.workout,
        sessionId: current.id,
        canControl: false,
      );
      final beforeRemaining = container.read(timer).remainingMs;
      final now = DateTime.now();
      final minute = now.hour * 60 + now.minute;
      final downgraded = BrandTemplate.initial().copyWith(
        storeName: 'Free standby',
        showCloudBoardLogo: true,
        blackScreenStartMinutes: (minute + 1435) % 1440,
        blackScreenEndMinutes: (minute + 5) % 1440,
      );
      expect(isBlackScreenTime(downgraded, now), isTrue);
      brands.add(downgraded);
      await pumpUntil(
        () =>
            container.read(effectiveBrandTemplateProvider).value ==
                downgraded &&
            playerReady(),
        'The brand update must arrive while the running slide remains visible',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(container.read(timer).remainingMs, lessThan(beforeRemaining));
      expect(container.read(timer).isPaused, isFalse);
      expect(
        tester.widget<WorkoutSlideCanvas>(canvasFinder).module,
        current.workout.modules.single,
      );
      expect(tester.element(find.byType(WorkoutPlayerScreen)), same(player));
      expect(find.byType(StoreWelcomeBoard), findsNothing);
      expect(find.text('Plus 알아보기'), findsNothing);
      // A regular Free projection turns off custom black-screen scheduling.
      brands.add(
        BrandTemplate.initial().copyWith(
          storeName: 'Free standby',
          showCloudBoardLogo: true,
        ),
      );
      sessions.add(null);
      await pumpUntil(
        () => find.byType(StoreWelcomeBoard).evaluate().length == 1,
        'The latest brand must render after the session ends',
      );
      expect(find.byType(WorkoutPlayerScreen), findsNothing);
      expect(
        tester
            .widget<StoreWelcomeBoard>(find.byType(StoreWelcomeBoard))
            .brand
            .storeName,
        'Free standby',
      );
      expect(
        find.byKey(const ValueKey('standby-cloudboard-logo')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await sessions.close();
      await brands.close();
    },
  );

  testWidgets(
    'TV paints a silent identification card and ACKs only while idle and connected',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final devices = StreamController<List<DisplayDevice>>.broadcast();
      final sessions = StreamController<PlaybackSession?>.broadcast();
      final connection = StreamController<bool>.broadcast();
      final actions = _PairActions();
      DisplayDevice identifying(String nonce, {bool expired = false}) =>
          DisplayDevice(
            id: 'tv',
            name: '메인 TV',
            zoneId: 'main',
            zoneName: 'main',
            online: true,
            lastSeenAtMs: 0,
            currentSessionId: null,
            acknowledgedRevision: 0,
            paired: true,
            identificationId: nonce,
            identificationExpiresAtMs:
                DateTime.now().millisecondsSinceEpoch + (expired ? -1 : 30000),
          );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            androidTvProvider.overrideWith((_) async => true),
            accountOwnerIdProvider.overrideWith((_) => Stream.value('u')),
            deviceIdProvider.overrideWith((_) async => 'tv'),
            deviceModeControllerProvider.overrideWith(_Mode.new),
            devicePairingControllerProvider.overrideWith(_Pair.new),
            devicePairingActionsProvider.overrideWithValue(actions),
            displayDevicesProvider.overrideWith((_) => devices.stream),
            activePlaybackSessionProvider.overrideWith((_) => sessions.stream),
            playbackConnectionProvider.overrideWith((_) => connection.stream),
            serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
            effectiveBrandTemplateProvider.overrideWith(
              (_) => Stream.value(BrandTemplate.initial()),
            ),
            workoutSchedulesProvider.overrideWith((_) => Stream.value([])),
          ],
          child: const MaterialApp(home: DisplayModeScreen()),
        ),
      );
      await tester.pump();
      connection.add(true);
      sessions.add(null);
      devices.add([identifying('nonce-4321')]);
      await tester.pumpAndSettle();
      expect(find.text('TV 연결 확인'), findsOneWidget);
      expect(find.text('4321'), findsOneWidget);
      expect(actions.identificationAcks, ['tv:nonce-4321']);
      sessions.add(running());
      devices.add([identifying('nonce-9999')]);
      await tester.pump();
      await tester.pump();
      expect(find.text('TV 연결 확인'), findsNothing);
      expect(actions.identificationAcks, ['tv:nonce-4321']);
      sessions.add(null);
      devices.add([identifying('nonce-0000', expired: true)]);
      await tester.pumpAndSettle();
      expect(find.text('TV 연결 확인'), findsNothing);
      connection.add(false);
      devices.add([identifying('nonce-1111')]);
      await tester.pumpAndSettle();
      expect(find.text('TV 연결 확인'), findsNothing);
      expect(actions.identificationAcks, ['tv:nonce-4321']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await devices.close();
      await sessions.close();
      await connection.close();
    },
  );

  for (final size in [const Size(390, 844), const Size(834, 1194)]) {
    testWidgets(
      'Display to Control replaces route and retains device at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('홈')),
            ),
            GoRoute(
              path: '/display',
              builder: (_, _) => const DisplayModeScreen(),
            ),
            GoRoute(
              path: '/displays',
              builder: (_, _) => const DisplaySettingsScreen(),
            ),
          ],
          initialLocation: '/display',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              androidTvProvider.overrideWith((ref) async => false),
              accountOwnerIdProvider.overrideWith((ref) => Stream.value('u')),
              deviceIdProvider.overrideWith((ref) async => 'tv'),
              deviceModeControllerProvider.overrideWith(_Mode.new),
              devicePairingControllerProvider.overrideWith(_Pair.new),
              displayDevicesProvider.overrideWith(
                (ref) => Stream.value([device('standby')]),
              ),
              activePlaybackSessionProvider.overrideWith(
                (ref) => Stream.value(null),
              ),
              playbackConnectionProvider.overrideWith(
                (ref) => Stream.value(true),
              ),
              serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
              effectiveBrandTemplateProvider.overrideWith(
                (ref) => Stream.value(BrandTemplate.initial()),
              ),
              workoutSchedulesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        final toggleRect = tester.getRect(
          find.byType(SegmentedButton<DeviceMode>),
        );
        await tester.tap(find.text('Control'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/displays');
        expect(router.canPop(), isFalse);
        expect(
          tester.getRect(find.byType(SegmentedButton<DeviceMode>)),
          toggleRect,
        );
        expect(find.text('매장 TV'), findsOneWidget);
        expect(
          tester
              .widget<SegmentedButton<DeviceMode>>(
                find.byType(SegmentedButton<DeviceMode>),
              )
              .selected,
          {DeviceMode.controller},
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'OFF uses standby, ON follows live session, ended session cannot return; reconnect and resume refresh',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final devices = StreamController<List<DisplayDevice>>.broadcast();
      final sessions = StreamController<PlaybackSession?>.broadcast();
      final connection = StreamController<bool>();
      var subscriptions = 0;
      var brand = BrandTemplate.initial().copyWith(
        blackScreenStartMinutes: 1,
        blackScreenEndMinutes: 0,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            androidTvProvider.overrideWith((ref) async => true),
            accountOwnerIdProvider.overrideWith((ref) => Stream.value('u')),
            deviceIdProvider.overrideWith((ref) async => 'tv'),
            deviceModeControllerProvider.overrideWith(_Mode.new),
            devicePairingControllerProvider.overrideWith(_Pair.new),
            devicePairingActionsProvider.overrideWithValue(_PairActions()),
            displayDevicesProvider.overrideWith((ref) => devices.stream),
            activePlaybackSessionProvider.overrideWith(
              (ref) => sessions.stream,
            ),
            playbackConnectionProvider.overrideWith((ref) => connection.stream),
            serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
            effectiveBrandTemplateProvider.overrideWith((ref) {
              subscriptions++;
              return Stream.value(brand);
            }),
            workoutSchedulesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: DisplayModeScreen()),
        ),
      );
      await tester.pump();
      connection.add(true);
      devices.add([device('standby')]);
      sessions.add(running());
      await tester.pumpAndSettle();
      expect(find.byType(StoreWelcomeBoard), findsOneWidget);
      expect(find.byType(DisplayRefreshButton), findsNothing);
      expect(find.byType(WorkoutPlayerScreen), findsNothing);
      devices.add([device('auto')]);
      await tester.pump();
      await tester.pump();
      expect(find.byType(WorkoutPlayerScreen), findsOneWidget);
      devices.add([device('standby')]);
      await tester.pump();
      await tester.pump();
      expect(find.byType(StoreWelcomeBoard), findsOneWidget);
      sessions.add(
        running().copyWith(
          status: PlaybackStatus.completed,
          remainingMs: 0,
          anchorServerMs: DateTime.now().millisecondsSinceEpoch - 10000,
        ),
      );
      devices.add([device('auto')]);
      await tester.pump();
      await tester.pump();
      expect(find.byType(WorkoutPlayerScreen), findsNothing);
      devices.add([device('standby')]);
      connection.add(false);
      await tester.pump();
      final before = subscriptions;
      brand = brand.copyWith(storeName: '변경한 매장');
      connection.add(true);
      await tester.pump();
      await tester.pump();
      expect(subscriptions, greaterThan(before));
      expect(
        tester
            .widget<StoreWelcomeBoard>(find.byType(StoreWelcomeBoard))
            .brand
            .storeName,
        '변경한 매장',
      );
      final beforeResume = subscriptions;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(subscriptions, greaterThan(beforeResume));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      unawaited(devices.close());
      unawaited(sessions.close());
      unawaited(connection.close());
      await tester.pumpAndSettle();
    },
  );
}
