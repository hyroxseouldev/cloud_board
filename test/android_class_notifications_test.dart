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
      String? expectedMethod;
      Completer<void>? observedMethod;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == expectedMethod &&
                observedMethod?.isCompleted == false) {
              observedMethod!.complete();
            }
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
      Future<void> settleProjection() async {
        // Streams and dependent providers each get a scheduler turn. No wall
        // clock assumption about an idle test host or native build load.
        await container.pump();
        await container.pump();
        await container.read(androidClassNotificationsProvider.future);
      }

      Future<void> expectNextMethod(
        String method,
        void Function() change,
      ) async {
        expectedMethod = method;
        observedMethod = Completer<void>();
        change();
        await observedMethod!.future.timeout(const Duration(seconds: 5));
        observedMethod = null;
        expectedMethod = null;
      }

      container.listen(androidClassNotificationsProvider, (_, _) {});
      await settleProjection();
      expect(
        calls,
        isEmpty,
        reason: 'Cold loading must preserve the native binding and dismissal',
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
        ).copyWith(modules: [WorkoutModule.empty('m').copyWith(name: 'Squat')]),
        stepIndex: 0,
        durationMs: 60000,
        deviceId: 'phone',
      ).toEntity();
      users.add(_User());
      await settleProjection();
      expect(
        calls,
        isEmpty,
        reason: 'Wait for the current session before clearing',
      );
      await expectNextMethod('show', () => sessions.add(session));
      expect(
        await container.read(androidClassNotificationsProvider.future),
        isFalse,
      );
      final payload = jsonDecode(calls.last.arguments as String) as Map;
      expect(payload['sessionId'], 'session');
      expect(payload['ownerId'], 'owner');
      expect((payload['steps'] as List).first['name'], 'Squat');
      await expectNextMethod(
        'clear',
        () => sessions.add(session.copyWith(status: PlaybackStatus.completed)),
      );
      expect(calls.last.method, 'clear');
      await expectNextMethod('show', () => sessions.add(session));
      await expectNextMethod('clear', () => users.add(null));
      expect(calls.last.method, 'clear');
    },
  );
}
