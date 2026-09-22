import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/display_settings_screen.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_refresh_button.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/views/display_mode_screen.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';

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

void main() {
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
              brandTemplateProvider.overrideWith(
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
            brandTemplateProvider.overrideWith((ref) {
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
