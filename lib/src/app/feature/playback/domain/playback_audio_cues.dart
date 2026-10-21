import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';

/// A cue's identity and server deadline never depend on a display's polling phase.
class PlaybackAudioCue {
  const PlaybackAudioCue(
    this.id,
    this.serverTimeMs,
    this.sound, {
    this.countdown = false,
  });
  final String id;
  final int serverTimeMs;
  final WorkoutSound sound;
  final bool countdown;
  String get soundKey => '${sound.name}:${countdown ? 'tick' : 'start'}';
}

class PlaybackAudioPlan {
  PlaybackAudioPlan(this.session)
    : phases = [
        for (final module in session.workout.modules)
          for (final phase in workoutModuleTimeline(module))
            (
              module: module,
              durationMs: phase.seconds * 1000,
              rest: phase.isRest,
            ),
      ];

  final PlaybackSession session;
  final List<({WorkoutModule module, int durationMs, bool rest})> phases;

  /// Fresh explicit commands have no advance notice. Allow one bounded cue,
  /// never use this on reattachment/foreground recovery or for automatic edges.
  PlaybackAudioCue? recentCommand(
    int serverNowMs, {
    PlaybackSession? previous,
  }) {
    final s = session;
    final age = serverNowMs - s.anchorServerMs;
    if (age < 0 ||
        age > 500 ||
        s.briefing ||
        s.workout.soundVolume <= 0 ||
        phases.isEmpty) {
      return null;
    }
    final identity = '${s.ownerId}/${s.id}/${s.revision}';
    if (s.startDelayMs > 0) {
      final second = s.startDelayMs ~/ 1000;
      if (s.status == PlaybackStatus.playing &&
          !s.timerCompleted &&
          second >= 1 &&
          second <= 3 &&
          s.startDelayMs == second * 1000 &&
          s.stepIndex >= 0 &&
          s.stepIndex < phases.length &&
          phases[s.stepIndex].module.beep &&
          s.workout.countdownSound != WorkoutSound.silent) {
        return PlaybackAudioCue(
          '$identity/prepare/$second',
          s.anchorServerMs,
          s.workout.countdownSound,
          countdown: true,
        );
      }
      return null;
    }
    final sameClass =
        previous != null &&
        previous.id == s.id &&
        previous.ownerId == s.ownerId;
    final priorPosition = sameClass
        ? playbackPosition(
            previous,
            playbackDurations(previous.workout),
            s.anchorServerMs,
          )
        : null;
    if (s.status == PlaybackStatus.completed || s.timerCompleted) {
      final index = s.stepIndex.clamp(0, phases.length - 1);
      // The scheduled natural end must not be followed by a second sound when
      // its server completion receipt arrives with a new revision.
      if (sameClass &&
          (previous.timerCompleted ||
              previous.status == PlaybackStatus.completed ||
              priorPosition!.index >= phases.length ||
              (phases[index].module.timerMode == WorkoutTimerMode.forTime &&
                  priorPosition.remainingMs == 0))) {
        return null;
      }
      if (!phases[index].module.beep ||
          s.workout.workoutEndSound == WorkoutSound.silent) {
        return null;
      }
      return PlaybackAudioCue(
        '$identity/end/$index',
        s.anchorServerMs,
        s.workout.workoutEndSound,
      );
    }
    if (s.status != PlaybackStatus.playing ||
        s.stepIndex < 0 ||
        s.stepIndex >= phases.length) {
      return null;
    }
    final first = phases[s.stepIndex];
    if (sameClass &&
        previous.status == PlaybackStatus.paused &&
        priorPosition!.index == s.stepIndex) {
      return null;
    }
    if (!first.module.beep || s.remainingMs != first.durationMs) return null;
    final sound = first.rest
        ? s.workout.restStartSound
        : s.workout.workStartSound;
    if (sound == WorkoutSound.silent) return null;
    return PlaybackAudioCue(
      '$identity/start/${s.stepIndex}',
      s.anchorServerMs,
      sound,
    );
  }

  /// Only future cues: reconnect and delayed preparation never replay old sounds.
  /// A five-second lookahead is refreshed independently of the UI's 100ms tick.
  List<PlaybackAudioCue> upcoming(int serverNowMs, {int horizonMs = 5000}) {
    final s = session;
    if (s.status != PlaybackStatus.playing ||
        s.briefing ||
        s.timerCompleted ||
        s.workout.soundVolume <= 0 ||
        s.stepIndex < 0 ||
        s.stepIndex >= phases.length) {
      return const [];
    }
    final cues = <PlaybackAudioCue>[];
    final endWindow = serverNowMs + horizonMs;
    final identity = '${s.ownerId}/${s.id}/${s.revision}';
    void add(String id, int at, WorkoutSound sound, {bool tick = false}) {
      if (at > serverNowMs && at <= endWindow && sound != WorkoutSound.silent) {
        cues.add(PlaybackAudioCue('$identity/$id', at, sound, countdown: tick));
      }
    }

    var start = s.anchorServerMs + s.startDelayMs;
    final first = phases[s.stepIndex];
    if (first.module.beep) {
      for (var second = 3; second >= 1; second--) {
        if (s.startDelayMs >= second * 1000) {
          add(
            'prepare/$second',
            start - second * 1000,
            s.workout.countdownSound,
            tick: true,
          );
        }
      }
      // Resuming halfway through a phase is not another phase-start cue.
      if (s.startDelayMs > 0 || s.remainingMs == first.durationMs) {
        add(
          'start/${s.stepIndex}',
          start,
          first.rest ? s.workout.restStartSound : s.workout.workStartSound,
        );
      }
    }
    for (var i = s.stepIndex; i < phases.length; i++) {
      final phase = phases[i];
      if (phase.durationMs == 0) break; // Open timer: no invented end/deadline.
      final duration = i == s.stepIndex ? s.remainingMs : phase.durationMs;
      final end = start + duration;
      if (phase.module.beep) {
        for (var second = 3; second >= 1; second--) {
          final at = end - second * 1000;
          if (at > start) {
            add('count/$i/$second', at, s.workout.countdownSound, tick: true);
          }
        }
      }
      if (phase.module.timerMode == WorkoutTimerMode.forTime ||
          i == phases.length - 1) {
        if (phase.module.beep) add('end/$i', end, s.workout.workoutEndSound);
        break; // Time cap waits for an explicit coach command.
      }
      final next = phases[i + 1];
      if (next.module.beep) {
        add(
          'start/${i + 1}',
          end,
          next.rest ? s.workout.restStartSound : s.workout.workStartSound,
        );
      }
      start = end;
      if (start > endWindow) break;
    }
    cues.sort((a, b) => a.serverTimeMs.compareTo(b.serverTimeMs));
    return cues.take(32).toList(growable: false);
  }
}
