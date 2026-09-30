import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/services/ios_class_controls.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'owner';
  @override
  bool get isAnonymous => false;
}

class _Mode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'iOS activity follows the class without requiring the player route',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel(
        'com.sunmkim.cloudboard/ios_class_controls',
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => calls.add(call));
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final sessions = StreamController<PlaybackSession?>();
      final users = StreamController<User?>();
      final connections = StreamController<bool>();
      final container = ProviderContainer(
        overrides: [
          firebaseAccountUserProvider.overrideWith((ref) => users.stream),
          deviceModeControllerProvider.overrideWith(_Mode.new),
          activePlaybackSessionProvider.overrideWith((ref) => sessions.stream),
          playbackConnectionProvider.overrideWith((ref) => connections.stream),
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(1500)),
          deviceIdProvider.overrideWith((ref) async => 'phone'),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(sessions.close);
      addTearDown(users.close);
      addTearDown(connections.close);
      container.listen(iosClassControlsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        calls,
        isEmpty,
        reason: 'Cold loading must preserve the native binding',
      );
      final session = PlaybackSessionModel.fromWorkout(
        id: 'session',
        ownerId: 'owner',
        zoneId: 'main',
        targetDeviceIds: ['tv'],
        workout: Workout.empty(
          'w',
          const WorkoutAuthor(
            id: 'owner',
            displayName: 'Coach',
            photoUrl: null,
          ),
        ).copyWith(name: 'Circuit', modules: [WorkoutModule.empty('m')]),
        stepIndex: 0,
        durationMs: 60000,
        deviceId: 'phone',
      ).toEntity();
      Future<void> settle() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await container.read(iosClassControlsProvider.future);
      }

      users.add(_User());
      sessions.add(session);
      connections.add(true);
      await settle();
      final payload = jsonDecode(calls.last.arguments as String) as Map;
      expect(payload['sessionId'], 'session');
      expect(payload['workoutName'], 'Circuit');
      expect(payload['serverOffsetMs'], 1500);
      expect(payload['connected'], isTrue);
      expect(payload.keys, isNot(contains('token')));
      sessions.add(
        session.copyWith(
          status: PlaybackStatus.paused,
          remainingMs: 23000,
          revision: 2,
        ),
      );
      await settle();
      expect(jsonDecode(calls.last.arguments as String)['remainingMs'], 23000);
      connections.add(false);
      await settle();
      expect(jsonDecode(calls.last.arguments as String)['connected'], isFalse);
      sessions.add(session.copyWith(status: PlaybackStatus.completed));
      await settle();
      expect(calls.last.method, 'clear');
      sessions.add(session);
      await settle();
      users.add(null);
      await settle();
      expect(calls.last.method, 'clear');
      users.add(_User());
      sessions.add(session.copyWith(targetDeviceIds: []));
      await settle();
      expect(calls.last.method, 'clear');
    },
  );
}
