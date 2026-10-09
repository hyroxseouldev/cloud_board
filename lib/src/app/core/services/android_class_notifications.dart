import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

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

part 'android_class_notifications.g.dart';

/// App-scoped projection only. Android's receiver owns notification commands,
/// including when there is no Flutter engine or player widget.
@Riverpod(keepAlive: true)
Future<bool> androidClassNotifications(Ref ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
  const channel = MethodChannel('com.sunmkim.cloudboard/class_controls');
  final auth = ref.watch(firebaseAccountUserProvider);
  final modeState = ref.watch(deviceModeControllerProvider);
  final sessionState = ref.watch(activePlaybackSessionProvider);
  final connected = ref.watch(playbackConnectionProvider).value ?? false;
  final offset = ref.watch(serverTimeOffsetProvider).value ?? 0;
  final deviceState = ref.watch(deviceIdProvider);
  if (!auth.isLoading &&
      !auth.hasError &&
      (auth.value == null || auth.value!.isAnonymous)) {
    await channel.invokeMethod<void>('clear');
    return true;
  }
  // A cold engine must not erase the native binding or a user's dismissal
  // while Firebase/provider state is still loading.
  if (auth.isLoading ||
      modeState.isLoading ||
      sessionState.isLoading ||
      deviceState.isLoading ||
      auth.hasError ||
      modeState.hasError ||
      sessionState.hasError ||
      deviceState.hasError) {
    return true;
  }
  final user = auth.value;
  final mode = modeState.value;
  final session = sessionState.value;
  final deviceId = deviceState.value;
  if (user == null ||
      user.isAnonymous ||
      mode != DeviceMode.controller ||
      session == null ||
      session.ownerId != user.uid ||
      deviceId == null ||
      session.status == PlaybackStatus.completed ||
      session.briefing ||
      session.targetDeviceIds.isEmpty) {
    await channel.invokeMethod<void>('clear');
    return true;
  }
  return await channel.invokeMethod<bool>(
        'show',
        jsonEncode({
          'ownerId': user.uid,
          'deviceId': deviceId,
          'sessionId': session.id,
          'revision': session.revision,
          'workoutName': session.workout.name,
          'status': session.status.name,
          'stepIndex': session.stepIndex,
          'remainingMs': session.remainingMs,
          'timerCompleted': session.timerCompleted,
          'anchorServerMs': session.anchorServerMs,
          'startDelayMs': session.startDelayMs,
          'serverOffsetMs': offset,
          'connected': connected,
          'steps': [
            for (final step in buildPlayerSteps(session.workout))
              {
                'durationMs': step.duration * 1000,
                'forTime': step.module.timerMode == WorkoutTimerMode.forTime,
                'countUp': timerCountsUp(step.module),
                'name': step.module.name,
                'label':
                    step.positionLabel ??
                    '${step.isRest ? '휴식' : '운동'} · ${step.set}/${step.totalSets}세트',
              },
          ],
        }),
      ) ??
      false;
}
