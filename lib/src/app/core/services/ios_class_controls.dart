import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';

part 'ios_class_controls.g.dart';

/// Non-secret session binding for App Intents. Native FirebaseAuth supplies the
/// current credential at invocation; no ID/refresh token crosses this channel.
@Riverpod(keepAlive: true)
Future<void> iosClassControls(Ref ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  const channel = MethodChannel('com.sunmkim.cloudboard/ios_class_controls');
  final auth = ref.watch(firebaseAccountUserProvider);
  final mode = ref.watch(deviceModeControllerProvider);
  final active = ref.watch(activePlaybackSessionProvider);
  final device = ref.watch(deviceIdProvider);
  // Don't erase a binding while a cold background invocation initializes Flutter.
  if (auth.isLoading ||
      mode.isLoading ||
      active.isLoading ||
      device.isLoading) {
    return;
  }
  if (auth.hasError || mode.hasError || active.hasError || device.hasError) {
    return;
  }
  final user = auth.value;
  final session = active.value;
  if (user == null ||
      user.isAnonymous ||
      mode.value != DeviceMode.controller ||
      session == null ||
      session.ownerId != user.uid ||
      session.status == PlaybackStatus.completed ||
      session.targetDeviceIds.isEmpty ||
      device.value == null) {
    await channel.invokeMethod<void>('clear');
    return;
  }
  await channel.invokeMethod<void>(
    'configure',
    jsonEncode({
      'ownerId': user.uid,
      'sessionId': session.id,
      'deviceId': device.value,
      'steps': [
        for (final step in buildPlayerSteps(session.workout))
          {'durationMs': step.duration * 1000, 'moduleIndex': step.moduleIndex},
      ],
    }),
  );
}
