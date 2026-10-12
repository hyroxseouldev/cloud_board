import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_preparation_controller.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/prepare_display_media.dart';
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
  final enabled = paired && deviceId != null;
  final offset = enabled ? ref.watch(serverTimeOffsetProvider).value ?? 0 : 0;
  final request = enabled
      ? ref.watch(displayPreparationRequestProvider(deviceId)).value
      : null;
  final repository = enabled
      ? ref.watch(displayPreparationRepositoryProvider)
      : null;
  useEffect(() {
    if (!enabled || !connected || !foreground) return null;
    Future<void> beat() async {
      try {
        await repository!.heartbeat(deviceId);
      } catch (_) {}
    }

    unawaited(beat());
    final timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(beat()),
    );
    return timer.cancel;
  }, [enabled, deviceId, repository, connected, foreground]);
  useEffect(
    () {
      if (!standby ||
          !enabled ||
          !connected ||
          !foreground ||
          request == null ||
          !request.targetDeviceIds.contains(deviceId) ||
          request.expired(preparationServerNow(offset))) {
        return null;
      }
      var cancelled = false;
      AudioPlayer? audioPlayer;
      Future<void> run() async {
        final attempt = ref
            .read(operationTelemetryProvider)
            .start('tv.prepare');
        final result = await prepareDisplayMedia(
          request,
          cancelled: () =>
              cancelled ||
              !context.mounted ||
              request.expired(preparationServerNow(offset)),
          images: (sources) => precacheWorkoutImages(
            context,
            sources,
            isCancelled: () => cancelled,
          ),
          audio: (sounds) async {
            if (sounds.isEmpty || cancelled) return;
            final player = audioPlayer = AudioPlayer();
            await player.setVolume(0);
            await player.setReleaseMode(ReleaseMode.stop);
            for (final sound in sounds) {
              if (cancelled) return;
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
        if (cancelled || result == null) {
          attempt.cancel();
        } else if (result.ready) {
          attempt.success();
        } else {
          attempt.failure('failed-precondition');
        }
        try {
          if (!cancelled && result != null) {
            await repository!.respond(
              deviceId,
              request,
              ready: result.ready,
              imageCount: result.imageCount,
              audioReady: result.audioReady,
            );
          }
        } catch (_) {
          /* Missing transport ACK is not shown as success on phone. */
        } finally {
          await audioPlayer?.dispose();
          audioPlayer = null;
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!cancelled) unawaited(run());
      });
      return () {
        cancelled = true;
        unawaited(audioPlayer?.dispose());
        audioPlayer = null;
      };
    },
    [
      enabled,
      deviceId,
      repository,
      standby,
      connected,
      foreground,
      request?.sessionId,
      request?.revision,
      request?.manifestHash,
      offset,
    ],
  );
}
