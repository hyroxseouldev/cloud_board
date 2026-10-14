import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/audience_branding.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/views/display_mode_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';

const audienceFree = AudienceBranding(
  ownerId: 'owner',
  revision: 1,
  projectionRevision: 1,
  appliedAtMs: 1,
  validUntilMs: 9999999999999,
  scope: AudienceLogoScope.allAudience,
  showCloudBoardLogo: true,
);

class AudienceFixture {
  AudienceFixture(
    WidgetTester tester, {
    this.policy = audienceFree,
    this.isTv = true,
    this.preferences = const DisplayPreferences(),
  }) {
    // Native keep-awake has no host in widget tests; reply without decoding the
    // Pigeon request. This also lets screenshot runAsync flush native futures.
    const wakelockChannel =
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      wakelockChannel,
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        wakelockChannel,
        null,
      ),
    );
    container = ProviderContainer(
      overrides: [
        androidTvProvider.overrideWith((_) async => isTv),
        accountOwnerIdProvider.overrideWith((_) => Stream.value('owner')),
        deviceIdProvider.overrideWith((_) async => 'tv'),
        deviceModeControllerProvider.overrideWith(_Mode.new),
        devicePairingControllerProvider.overrideWith(_Pair.new),
        devicePairingActionsProvider.overrideWithValue(_PairActions()),
        displayDevicesProvider.overrideWith((_) => devices.stream),
        activePlaybackSessionProvider.overrideWith((_) => sessions.stream),
        playbackConnectionProvider.overrideWith((_) => Stream.value(true)),
        serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
        playerClockProvider.overrideWith((_) => tester.binding.clock.now),
        effectiveBrandTemplateProvider.overrideWith((_) => brands.stream),
        audienceBrandingProvider.overrideWith((_) => policy),
        workoutSchedulesProvider.overrideWith((_) => Stream.value([])),
      ],
    );
  }
  AudienceBranding? policy;
  final bool isTv;
  final DisplayPreferences preferences;
  late final ProviderContainer container;
  final sessions = StreamController<PlaybackSession?>.broadcast();
  final devices = StreamController<List<DisplayDevice>>.broadcast();
  final brands = StreamController<BrandTemplate>.broadcast();

  Widget app({Widget? screen}) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: XonTheme.light,
      home: screen ?? const DisplayModeScreen(),
    ),
  );
  void setPolicy(AudienceBranding? value) {
    policy = value;
    container.invalidate(audienceBrandingProvider);
  }

  void display(String state) => devices.add([
    DisplayDevice(
      id: 'tv',
      name: '관객 화면',
      zoneId: 'main',
      zoneName: '수업 공간',
      online: true,
      lastSeenAtMs: 0,
      currentSessionId: null,
      acknowledgedRevision: 0,
      paired: true,
      displayState: state,
      preferences: preferences,
    ),
  ]);
  void start() {
    display('auto');
    sessions.add(null);
    brands.add(
      BrandTemplate.initial().copyWith(
        storeName: '센터의 다음 수업',
        standbyMessage: '잠시 후 수업을 시작합니다',
        showCloudBoardLogo: false,
      ),
    );
  }

  bool _disposed = false;
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
    await sessions.close();
    await devices.close();
    await brands.close();
  }
}

// A valid RGB checker PNG (320×180), generated from four solid fixture colors.
// Distinct from the app's generated slide artwork and logo asset.
const audienceImage =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAUAAAAC0CAIAAABqhmJGAAAEnUlEQVR4nO3TQQ0CQRREwS8EFyhAwYY7FtbHJsjZO9qQMZmXSlpBV948XseSPT/vJTuvc8l+93fJ+LZ9B3AbmG/bV8BxYL5tXwHHgfm2fQUcB+bb9hVwHJhv21fAcWC+bV8Bx4H5tn0FHAfm2/YVcByYb9tXwHFgvm1fAceB+bZ9BRwH5tv2FXAcmG/bV8BxYL5tXwHHgfm2fQUcB+bb9hVwHJhv21fAcWC+bV8Bx4H5tn0FHAfm2/YVcByYb9tXwHFgvm1fAceB+bZ9BRwH5tv2FXAcmG/bV8BxYL5tXwHHgfm2fQUcB+bb9hVwHJhv23ccLSS++/oKOA7Mt+0r4Dgw37avgOPAfNu+Ao4D8237CjgOzLftK+A4MN+2r4DjwHzbvgKOA/Nt+wo4Dsy37SvgODDftq+A48B8274CjgPzbfsKOA7Mt+0r4Dgw37avgOPAfNu+Ao4D8237CjgOzLftK+A4MN+2r4DjwHzbvgKOA/Nt+wo4Dsy37SvgODDftq+A48B8274CjgPzbfsKOA7Mt+0r4Dgw37avgOPAfNu+Ao4D8237CjgOzLftO44WEt99fQUcB+bb9hVwHJhv21fAcWC+bV8Bx4H5tn0FHAfm2/YVcByYb9tXwHFgvm1fAceB+bZ9BRwH5tv2FXAcmG/bV8BxYL5tXwHHgfm2fQUcB+bb9hVwHJhv21fAcWC+bV8Bx4H5tn0FHAfm2/YVcByYb9tXwHFgvm1fAceB+bZ9BRwH5tv2FXAcmG/bV8BxYL5tXwHHgfm2fQUcB+bb9hVwHJhv21fAcWC+bV8Bx4H5tn0FHAfm2/YdRwuJ776+Ao4D8237CjgOzLftK+A4MN+2r4DjwHzbvgKOA/Nt+wo4Dsy37SvgODDftq+A48B8274CjgPzbfsKOA7Mt+0r4Dgw37avgOPAfNu+Ao4D8237CjgOzLftK+A4MN+2r4DjwHzbvgKOA/Nt+wo4Dsy37SvgODDftq+A48B8274CjgPzbfsKOA7Mt+0r4Dgw37avgOPAfNu+Ao4D8237CjgOzLftK+A4MN+2r4DjwHzbvgKOA/Nt+46jhcR3X18Bx4H5tn0FHAfm2/YVcByYb9tXwHFgvm1fAceB+bZ9BRwH5tv2FXAcmG/bV8BxYL5tXwHHgfm2fQUcB+bb9hVwHJhv21fAcWC+bV8Bx4H5tn0FHAfm2/YVcByYb9tXwHFgvm1fAceB+bZ9BRwH5tv2FXAcmG/bV8BxYL5tXwHHgfm2fQUcB+bb9hVwHJhv21fAcWC+bV8Bx4H5tn0FHAfm2/YVcByYb9tXwHFgvm1fAceB+bZ9x9FC4ruvr4DjwHzbvgKOA/Nt+wo4Dsy37SvgODDftq+A48B8274CjgPzbfsKOA7Mt+0r4Dgw37avgOPAfNu+Ao4D8237CjgOzLftK+A4MN+2r4DjwHzbvgKOA/Nt+wo4Dsy37SvgODDftq+A48B8274CjgPzbfsKOA7Mt+0r4Dgw37avgOPAfNu+Ao4D8237CjgOzLftK+A4MN+2r4DjwHzbvgKOA/Nt+wo4Dsy37SvgODDftq+A48B8275/wRN6rSY7xREAAAAASUVORK5CYII=';

Workout audienceWorkout({bool bright = false, bool image = false}) =>
    Workout.empty(
      'audience',
      const WorkoutAuthor(id: 'owner', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      name: '오늘의 수업',
      brandL: '사용자 왼쪽 문구',
      brandR: '사용자 오른쪽 문구',
      countdownSeconds: 10,
      countdownSound: WorkoutSound.silent,
      workStartSound: WorkoutSound.silent,
      restStartSound: WorkoutSound.silent,
      workoutEndSound: WorkoutSound.silent,
      modules: [
        WorkoutModule.empty('interval').copyWith(
          name: 'WARM UP',
          imageSource: image ? audienceImage : '',
          coverImage: image,
          appearance: SlideAppearance(
            brandColor: bright ? 0xFF2B332E : 0xFFFFFFFF,
            setsColor: bright ? 0xFF2B332E : 0xB3FFFFFF,
          ),
          text: '10 AIR SQUATS\n8 PUSH UPS\n20 SEC PLANK',
          workSeconds: 60,
          sets: 2,
          restSeconds: 15,
          beep: false,
          designTemplate: bright ? 'studio-v1-list' : null,
          designBackgroundColor: bright ? 0xFFF7F5EF : null,
          designTextColor: bright ? 0xFF2B332E : null,
          designAccentColor: bright ? 0xFF526B60 : null,
        ),
      ],
    );
PlaybackSession audienceSession(
  WidgetTester tester, {
  Workout? workout,
  int delay = 0,
  int step = 0,
  bool paused = false,
  bool briefing = false,
  int revision = 1,
}) => PlaybackSession(
  id: 'session',
  ownerId: 'owner',
  zoneId: 'main',
  targetDeviceIds: ['tv'],
  workout: workout ?? audienceWorkout(),
  status: paused ? PlaybackStatus.paused : PlaybackStatus.playing,
  briefing: briefing,
  startDelayMs: delay,
  stepIndex: step,
  remainingMs: step == 1 ? 15000 : 60000,
  anchorServerMs: tester.binding.clock.now().millisecondsSinceEpoch,
  revision: revision,
  updatedByDeviceId: 'phone',
);

Future<void> audiencePumpUntil(
  WidgetTester tester,
  bool Function() ready,
  String reason,
) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (ready()) return;
  }
  expect(ready(), isTrue, reason: reason);
}

class _Mode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.display;
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
