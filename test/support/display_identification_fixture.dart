import 'dart:async';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/views/display_mode_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const identificationLongName = '서울 성수 스튜디오 3층 그룹 트레이닝 공간 창가 쪽 두 번째 디스플레이';

DisplayDevice identificationDevice(
  String id,
  String name,
  String nonce, {
  int? expiresAtMs,
  String? acknowledgement,
}) => DisplayDevice(
  id: id,
  name: name,
  zoneId: 'main',
  zoneName: '수업 공간',
  online: true,
  lastSeenAtMs: 0,
  currentSessionId: null,
  acknowledgedRevision: 0,
  paired: true,
  identificationId: nonce,
  identificationAck: acknowledgement,
  identificationExpiresAtMs:
      expiresAtMs ?? DateTime.now().millisecondsSinceEpoch + 30000,
);

class IdentificationFixture {
  IdentificationFixture(
    WidgetTester tester, {
    this.deviceId = 'tv',
    this.isTv = true,
  }) {
    const channel =
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      channel,
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        channel,
        null,
      ),
    );
    container = ProviderContainer(
      overrides: [
        androidTvProvider.overrideWith((_) async => isTv),
        accountOwnerIdProvider.overrideWith((_) => Stream.value('owner')),
        deviceIdProvider.overrideWith((_) async => deviceId),
        deviceModeControllerProvider.overrideWith(_Mode.new),
        devicePairingControllerProvider.overrideWith(_Pair.new),
        devicePairingActionsProvider.overrideWithValue(actions),
        displayDevicesProvider.overrideWith((_) => devices.stream),
        activePlaybackSessionProvider.overrideWith((_) => sessions.stream),
        playbackConnectionProvider.overrideWith((_) => connection.stream),
        serverTimeOffsetProvider.overrideWith((_) => offset.stream),
        playerClockProvider.overrideWith((_) => tester.binding.clock.now),
        effectiveBrandTemplateProvider.overrideWith(
          (_) => Stream.value(BrandTemplate.initial()),
        ),
        audienceBrandingProvider.overrideWith((_) => null),
        workoutSchedulesProvider.overrideWith((_) => Stream.value([])),
        beepPlayerProvider.overrideWithValue(sound),
      ],
    );
  }
  final String deviceId;
  final bool isTv;
  late final ProviderContainer container;
  final actions = IdentificationActions();
  final sound = IdentificationSound();
  final devices = StreamController<List<DisplayDevice>>.broadcast();
  final sessions = StreamController<PlaybackSession?>.broadcast();
  final connection = StreamController<bool>.broadcast();
  final offset = StreamController<int>.broadcast();
  bool _disposed = false;

  Widget app({double textScale = 1}) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: XonTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const DisplayModeScreen(),
    ),
  );
  void start(List<DisplayDevice> values) {
    offset.add(0);
    connection.add(true);
    sessions.add(null);
    devices.add(values);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
    await Future.wait([
      devices.close(),
      sessions.close(),
      connection.close(),
      offset.close(),
    ]);
  }
}

class IdentificationActions implements DevicePairingActions {
  final acknowledgements = <String>[];
  @override
  Future<void> acknowledgeIdentification(String deviceId, String nonce) async {
    acknowledgements.add('$deviceId:$nonce');
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

class IdentificationSound implements BeepPlayer {
  int calls = 0;
  @override
  Future<void> play([
    WorkoutSound sound = WorkoutSound.classicBeep,
    double volume = 1,
  ]) async {
    calls++;
  }

  @override
  Future<void> playCountdown(WorkoutSound sound, double volume) async {
    calls++;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> setEnabled(bool enabled) async {}
  @override
  Future<void> dispose() async {}
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
