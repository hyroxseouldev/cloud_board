import 'package:cloud_board/src/app/feature/device/domain/usecases/complete_display_preparation.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/display_image_retention.dart';
import 'package:cloud_board/src/app/core/runtime_policy/display_heartbeat_policy_service.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_heartbeat_policy.dart';

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/prepare_display_media.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/retry_display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_preparation_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';

void useDisplayPreparation(
  BuildContext context,
  WidgetRef ref, {
  required String? deviceId,
  required bool paired,
  required bool standby,
  required bool connected,
  required bool foreground,
  String? ownerId,
  String? connectionId,
  DisplayHeartbeatPolicy initialHeartbeatPolicy = DisplayHeartbeatPolicy.target,
}) {
  final enabled = paired && deviceId != null && foreground && connected;
  final offset = enabled ? ref.watch(serverTimeOffsetProvider).value ?? 0 : 0;
  final requestValue = enabled
      ? ref.watch(displayPreparationRequestProvider(deviceId))
      : null;
  final request =
      requestValue == null || requestValue.isLoading || requestValue.hasError
      ? null
      : requestValue.value;
  final repository = enabled
      ? ref.watch(displayPreparationRepositoryProvider)
      : null;

  final reporter = ref.watch(errorReporterProvider);
  final telemetry = ref.watch(operationTelemetryProvider);
  final heartbeatSelection = useMemoized(
    () => DisplayHeartbeatSelection(initialHeartbeatPolicy),
    [ownerId, deviceId, connectionId],
  );
  heartbeatSelection.setStandby(standby);

  useEffect(() {
    if (!enabled || !standby || ownerId == null || connectionId == null) {
      return null;
    }
    var cancelled = false;
    unawaited(() async {
      final policy = await ref
          .read(displayHeartbeatPolicyServiceProvider)
          .load();
      if (!cancelled && context.mounted) {
        heartbeatSelection.pending = policy;
      }
    }());
    return () => cancelled = true;
  }, [enabled, standby, ownerId, connectionId, heartbeatSelection]);

  void health(String stage, String? code, int attempt, {String? requestId}) {
    if (repository == null || deviceId == null) return;
    unawaited(
      repository
          .reportHealth(
            deviceId,
            stage: stage,
            code: code,
            attempt: attempt,
            requestId: requestId,
          )
          .catchError((Object _) {}),
    );
  }

  useEffect(() {
    if (!enabled) return null;
    var cancelled = false;
    var busy = false;
    var permissionStopped = false;
    Timer? timer;
    var interval = heartbeatSelection.applied.interval;
    Future<void> beat() async {
      if (busy || cancelled || permissionStopped) return;
      busy = true;
      final selectedPolicy = heartbeatSelection.begin();
      try {
        final result = await retryDisplayPreparation<bool>(
          operation: () async {
            try {
              await repository!
                  .heartbeat(
                    deviceId,
                    policy: connectionId == null ? null : selectedPolicy,
                    connectionId: connectionId,
                  )
                  .timeout(const Duration(seconds: 8));
              return true;
            } catch (error, stack) {
              if (!cancelled && context.mounted) {
                reporter.capture(
                  error,
                  stack,
                  action: 'tv.prepare.heartbeat',
                  context: {'preparationStage': 'heartbeat'},
                );
              }
              rethrow;
            }
          },
          cancelled: () => cancelled || !context.mounted,
          onFailure: (code, attempt) {
            permissionStopped =
                code == 'permission-denied' || code == 'unauthenticated';
            health('heartbeat', code, attempt);
          },
        );
        if (result == true && !cancelled && context.mounted) {
          heartbeatSelection.accepted(selectedPolicy);
          health('heartbeat', null, 1);
          if (interval != selectedPolicy.interval) {
            // Advertise the complete policy successfully before slowing down.
            interval = selectedPolicy.interval;
            timer?.cancel();
            timer = Timer.periodic(interval, (_) => unawaited(beat()));
          }
        } else if (!cancelled) {
          heartbeatSelection.failed();
        }
      } finally {
        busy = false;
      }
    }

    unawaited(beat());
    timer = Timer.periodic(interval, (_) => unawaited(beat()));
    return () {
      cancelled = true;
      timer?.cancel();
    };
  }, [enabled, deviceId, repository, connectionId, heartbeatSelection]);

  useEffect(
    () {
      if (!standby ||
          !enabled ||
          request == null ||
          !request.targetDeviceIds.contains(deviceId) ||
          request.expired(preparationServerNow(offset))) {
        return null;
      }
      var cancelled = false;
      AudioPlayer? audioPlayer;
      bool stopped() =>
          cancelled ||
          !context.mounted ||
          request.expired(preparationServerNow(offset));

      final retainedImages = ref.read(displayImageRetentionProvider);
      retainedImages.prepare(
        request.sessionId,
        Duration(
          milliseconds: request.expiresAtMs - preparationServerNow(offset),
        ),
        sources: request.images,
      );
      Future<void> run() async {
        final attempt = telemetry.start('tv.prepare');
        var failureCode = 'prepare_images';
        void capture(String stage, Object error, StackTrace stack) {
          if (stopped()) return;
          failureCode = switch (stage) {
            'audio' => 'prepare_audio',
            'response' => 'prepare_response',
            'heartbeat' => operationFailureCode(error),
            _ => 'prepare_images',
          };
          reporter.capture(
            error,
            stack,
            action: 'tv.prepare.$stage',
            context: {
              'operationId': attempt.id,
              'preparationStage': stage,
              'sessionId': request.sessionId,
              'expectedRevision': request.revision,
            },
          );
        }

        Future<void> observed(
          String stage,
          Future<void> Function() operation,
        ) async {
          try {
            await operation();
          } catch (error, stack) {
            capture(stage, error, stack);
            rethrow;
          }
        }

        try {
          final outcome = await completeDisplayPreparation(
            cancelled: stopped,
            health: (stage, code, attempt) =>
                health(stage, code, attempt, requestId: request.sessionId),
            prepare: () async {
              await audioPlayer?.dispose();
              audioPlayer = null;
              var attemptFinished = false;
              bool attemptStopped() => attemptFinished || stopped();
              try {
                return await prepareDisplayMedia(
                  request,
                  cancelled: attemptStopped,
                  onError: capture,
                  images: (sources) => precacheWorkoutImages(
                    context,
                    sources,
                    isCancelled: attemptStopped,
                    retention: retainedImages,
                  ),
                  audio: (sounds) async {
                    if (sounds.isEmpty || attemptStopped()) return;
                    final scheduledAudio = ref.read(androidCueAudioProvider);
                    if (scheduledAudio != null) {
                      // This is the SAME retained SoundPool used by playback.
                      // No sound or audio focus is requested during preparation.
                      for (final sound in sounds) {
                        if (attemptStopped()) return;
                        final value = WorkoutSound.values.firstWhere(
                          (v) => v.name == sound,
                        );
                        await prepareAndroidCue(scheduledAudio, value);
                        if (attemptStopped()) return;
                        await prepareAndroidCue(
                          scheduledAudio,
                          value,
                          countdown: true,
                        );
                      }
                      return;
                    }
                    final player = audioPlayer = AudioPlayer();
                    await player.setVolume(0);
                    if (attemptStopped()) return;
                    await player.setReleaseMode(ReleaseMode.stop);
                    for (final sound in sounds) {
                      if (attemptStopped()) return;
                      final value = WorkoutSound.values
                          .where((v) => v.name == sound)
                          .first;
                      final source = await workoutSoundSource(value);
                      if (attemptStopped()) return;
                      await player.setSource(source);
                      if (attemptStopped()) return;
                      if (value == WorkoutSound.videoBeep) {
                        final tick = await workoutSoundSource(
                          value,
                          countdown: true,
                        );
                        if (attemptStopped()) return;
                        await player.setSource(tick);
                      }
                    }
                  },
                );
              } finally {
                // A native call may finish after timeout/disposal. It must not
                // proceed to another source or touch the next retry's player.
                attemptFinished = true;
              }
            },
            respond: (media, ready) => observed(
              'response',
              () => repository!
                  .respond(
                    deviceId,
                    request,
                    ready: ready,
                    imageCount: media.imageCount,
                    audioReady: media.audioReady,
                  )
                  .timeout(const Duration(seconds: 8)),
            ),
            heartbeat: () => observed(
              'heartbeat',
              () => repository!
                  .heartbeat(deviceId, ready: true, connectionId: connectionId)
                  .timeout(const Duration(seconds: 8)),
            ),
          );
          switch (outcome) {
            case DisplayPreparationOutcome.ready:
              attempt.success();
            case DisplayPreparationOutcome.failed:
              attempt.failure(failureCode);
            case DisplayPreparationOutcome.cancelled:
              attempt.cancel();
          }
        } finally {
          await audioPlayer?.dispose();
          audioPlayer = null;
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!stopped()) unawaited(run());
      });
      return () {
        cancelled = true;
        // Disposal is serialized by the running preparation's finally block.
      };
    },
    [
      enabled,
      deviceId,
      connectionId,
      repository,
      standby,
      request?.sessionId,
      request?.revision,
      request?.manifestHash,
      offset,
    ],
  );
}
