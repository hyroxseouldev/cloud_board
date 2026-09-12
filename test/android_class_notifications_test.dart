import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/core/services/android_class_notifications.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
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
  const channel = MethodChannel('com.sunmkim.cloudboard/class_controls');
  test(
    'app-scoped projection updates and clears without a player widget',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'show'
                ? false
                : null; // Permission denial is nonfatal.
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final sessions = StreamController<PlaybackSession?>();
      final users = StreamController<User?>();
      final container = ProviderContainer(
        overrides: [
          firebaseAccountUserProvider.overrideWith((ref) => users.stream),
          deviceModeControllerProvider.overrideWith(_Mode.new),
          activePlaybackSessionProvider.overrideWith((ref) => sessions.stream),
          playbackConnectionProvider.overrideWith((ref) => Stream.value(true)),
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
          deviceIdProvider.overrideWith((ref) async => 'phone'),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(sessions.close);
      addTearDown(users.close);
      container.listen(androidClassNotificationsProvider, (_, _) {});
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
        ).copyWith(modules: [WorkoutModule.empty('m').copyWith(name: 'Squat')]),
        stepIndex: 0,
        durationMs: 60000,
        deviceId: 'phone',
      ).toEntity();
      users.add(_User());
      sessions.add(session);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        await container.read(androidClassNotificationsProvider.future),
        isFalse,
      );
      final payload = jsonDecode(calls.last.arguments as String) as Map;
      expect(payload['sessionId'], 'session');
      expect(payload['ownerId'], 'owner');
      expect((payload['steps'] as List).first['name'], 'Squat');
      sessions.add(session.copyWith(status: PlaybackStatus.completed));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(calls.last.method, 'clear');
      sessions.add(session);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      users.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(calls.last.method, 'clear');
    },
  );
}
