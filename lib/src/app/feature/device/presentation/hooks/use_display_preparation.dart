import 'package:cloud_board/src/app/feature/device/domain/usecases/complete_display_preparation.dart';

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

  void health(String stage, String? code, int attempt, {String? requestId}) {
    if (repository == null || deviceId == null) return;
    if (code != null) {
      ref
          .read(errorReporterProvider)
          .capture(
            StateError('TV preparation stage failed'),
            StackTrace.current,
            action: 'tv.prepare.$stage',
            context: {'code': code, 'attempt': attempt},
          );
    }
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
    Future<void> beat() async {
      if (busy || cancelled || permissionStopped) return;
      busy = true;
      try {
        final result = await retryDisplayPreparation<bool>(
          operation: () async {
            await repository!
                .heartbeat(deviceId)
                .timeout(const Duration(seconds: 8));
            return true;
          },
          cancelled: () => cancelled || !context.mounted,
          onFailure: (code, attempt) {
            permissionStopped =
                code == 'permission-denied' || code == 'unauthenticated';
            health('heartbeat', code, attempt);
          },
        );
        if (result == true) health('heartbeat', null, 1);
      } finally {
        busy = false;
      }
    }

    unawaited(beat());
    final timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(beat()),
    );
    return () {
      cancelled = true;
      timer.cancel();
    };
  }, [enabled, deviceId, repository]);

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

      Future<void> run() async {
        final telemetry = ref
            .read(operationTelemetryProvider)
            .start('tv.prepare');
        try {
          final outcome = await completeDisplayPreparation(
            cancelled: stopped,
            health: (stage, code, attempt) =>
                health(stage, code, attempt, requestId: request.sessionId),
            prepare: () async {
              await audioPlayer?.dispose();
              audioPlayer = null;
              return prepareDisplayMedia(
                request,
                cancelled: stopped,
                images: (sources) => precacheWorkoutImages(
                  context,
                  sources,
                  isCancelled: stopped,
                ),
                audio: (sounds) async {
                  if (sounds.isEmpty || stopped()) return;
                  final player = audioPlayer = AudioPlayer();
                  await player.setVolume(0);
                  await player.setReleaseMode(ReleaseMode.stop);
                  for (final sound in sounds) {
                    if (stopped()) return;
                    final value = WorkoutSound.values
                        .where((v) => v.name == sound)
                        .first;
                    await player.setSource(workoutSoundSource(value));
                    if (value == WorkoutSound.videoBeep) {
                      await player.setSource(
                        workoutSoundSource(value, countdown: true),
                      );
                    }
                  }
                },
              );
            },
            respond: (media, ready) => repository!
                .respond(
                  deviceId,
                  request,
                  ready: ready,
                  imageCount: media.imageCount,
                  audioReady: media.audioReady,
                )
                .timeout(const Duration(seconds: 8)),
            heartbeat: () => repository!
                .heartbeat(deviceId, ready: true)
                .timeout(const Duration(seconds: 8)),
          );
          switch (outcome) {
            case DisplayPreparationOutcome.ready:
              telemetry.success();
            case DisplayPreparationOutcome.failed:
              telemetry.failure('failed-precondition');
            case DisplayPreparationOutcome.cancelled:
              telemetry.cancel();
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
      repository,
      standby,
      request?.sessionId,
      request?.revision,
      request?.manifestHash,
      offset,
    ],
  );
}
