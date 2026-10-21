// Local-only native smoke harness. No Firebase initialization, account or server.
// flutter run --debug --flavor development -t tool/android_beep_smoke.dart -d <local-emulator>
// Observe: adb logcat -s CloudBoardCue ; nativePlay is NOT speaker onset.
import 'dart:async';

import 'package:cloud_board/src/app/core/services/android_cue_audio.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/display_playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';

import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: BeepSmoke()));
}

class BeepSmoke extends StatefulWidget {
  const BeepSmoke({super.key});
  @override
  State<BeepSmoke> createState() => _BeepSmokeState();
}

class _BeepSmokeState extends State<BeepSmoke> {
  final audio = AndroidCueAudio();
  ProviderContainer? container;
  ProviderSubscription<PlayerState>? player;
  String status = 'LOCAL ONLY · no Firebase · emulator only';
  int revision = 0;
  Future<void> start() async {
    player?.close();
    container?.dispose();
    try {
      await prepareAndroidCue(audio, WorkoutSound.videoBeep);
      await prepareAndroidCue(audio, WorkoutSound.videoBeep, countdown: true);
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final workout =
          Workout.empty(
            'local',
            const WorkoutAuthor(
              id: 'local',
              displayName: 'Local',
              photoUrl: null,
            ),
          ).copyWith(
            soundVolume: 0.1,
            modules: [
              WorkoutModule.empty('m').copyWith(
                workSeconds: 5,
                restSeconds: 4,
                sets: 1,
                includeFinalRest: true,
                beep: true,
              ),
            ],
          );
      final session = PlaybackSession(
        id: 'local-smoke',
        ownerId: 'local',
        zoneId: 'local',
        workout: workout,
        status: PlaybackStatus.playing,
        startDelayMs: 4000,
        stepIndex: 0,
        remainingMs: 5000,
        anchorServerMs: now,
        revision: ++revision,
        updatedByDeviceId: 'local',
      );
      final scope = ProviderContainer(
        overrides: [
          androidCueAudioProvider.overrideWithValue(audio),
          displayPlaybackSessionProvider.overrideWith(
            () => _LocalSession(session),
          ),
          serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
        ],
      );
      container = scope;
      player = scope.listen(
        playerControllerProvider(
          workout,
          sessionId: session.id,
          canControl: false,
        ),
        (_, next) {
          if (mounted) {
            setState(
              () => status = next.index >= next.steps.length
                  ? 'Local player complete; final sound tail must finish (inspect logs)'
                  : 'revision $revision / step ${next.index} / remaining ${next.remainingMs}',
            );
          }
        },
        fireImmediately: true,
      );
    } catch (error) {
      if (mounted) setState(() => status = 'FAILED: $error');
    }
  }

  @override
  void dispose() {
    player?.close();
    container?.dispose();
    unawaited(audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Local Android beep smoke')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(status),
          ElevatedButton(
            onPressed: start,
            child: const Text('Preload + schedule fixture'),
          ),
          OutlinedButton(
            onPressed: () {
              player?.close();
              container?.dispose();
              setState(() => status = 'Cancelled; no queued cue should play');
            },
            child: const Text('Cancel'),
          ),
          const Text(
            'Starting again replaces the owner and revision. Background cancels native callbacks; returning admits only future cues.',
          ),
        ],
      ),
    ),
  );
}

// The real player completion path is exercised, without recovery/network I/O.
class _LocalSession extends DisplayPlaybackSession {
  _LocalSession(this.initial);
  final PlaybackSession initial;
  @override
  PlaybackSession? build() => initial;
  @override
  bool finishLocally(String sessionId) {
    if (state?.status != PlaybackStatus.playing) return false;
    state = state!.copyWith(status: PlaybackStatus.completed);
    return true;
  }
}
