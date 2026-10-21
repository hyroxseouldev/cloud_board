import 'dart:async';

import 'package:cloud_board/src/app/core/services/android_cue_audio.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_audio_cues.dart';

/// One foreground attachment; native owner checks also reject late async work.
class AndroidWorkoutCues {
  AndroidWorkoutCues({
    required this.audio,
    required this.plan,
    required this.offsetMs,
    required this.nowMs,
    required this.onFailure,
  }) : owner = 'audio-${++_nextOwner}';
  static int _nextOwner = 0;
  final String owner;
  final AndroidCueAudio audio;
  final PlaybackAudioPlan plan;
  final int offsetMs;
  final int Function() nowMs;
  final void Function(Object, StackTrace) onFailure;
  Timer? _refresh;
  bool _cancelled = false;
  bool _hardCancelled = false;
  bool _updating = false;

  Future<void> start({PlaybackAudioCue? explicitCue}) async {
    try {
      await audio.activate(
        owner,
        terminalCueId: explicitCue?.id.contains('/end/') == true
            ? explicitCue!.id
            : null,
      );
      if (_cancelled) return;
      final workout = plan.session.workout;
      await Future.wait([
        for (final entry in {
          (workout.countdownSound, true),
          (workout.workStartSound, false),
          (workout.restStartSound, false),
          (workout.workoutEndSound, false),
        })
          prepareAndroidCue(audio, entry.$1, countdown: entry.$2),
      ]);
      if (_cancelled) return;
      await refresh();
      if (!_cancelled &&
          explicitCue != null &&
          nowMs() + offsetMs - explicitCue.serverTimeMs <= 500) {
        await audio.immediate(owner, {
          'id': explicitCue.id,
          'key': explicitCue.soundKey,
          'localDeadlineMs': explicitCue.serverTimeMs - offsetMs,
        }, plan.session.workout.soundVolume);
      }
      if (!_cancelled) {
        _refresh = Timer.periodic(
          const Duration(milliseconds: 500),
          (_) => unawaited(refresh()),
        );
      }
    } catch (error, stack) {
      _fail(error, stack);
    }
  }

  Future<void> refresh() async {
    if (_cancelled || _updating) return;
    _updating = true;
    try {
      final cues = plan.upcoming(nowMs() + offsetMs);
      await audio.replace(owner, [
        for (final cue in cues)
          {
            'id': cue.id, 'key': cue.soundKey,
            // Native converts local wall time to monotonic uptime once on receipt.
            'localDeadlineMs': cue.serverTimeMs - offsetMs,
          },
      ], plan.session.workout.soundVolume);
    } catch (error, stack) {
      _fail(error, stack);
    } finally {
      _updating = false;
    }
  }

  void _fail(Object error, StackTrace stack) {
    if (_cancelled) return;
    cancel();
    onFailure(error, stack);
  }

  void cancel({bool preserveEnd = false}) {
    if (_cancelled && (preserveEnd || _hardCancelled)) return;
    _cancelled = true;
    _hardCancelled = !preserveEnd;
    _refresh?.cancel();
    unawaited(
      audio.cancel(owner, preserveEnd: preserveEnd).catchError((Object _) {}),
    );
  }
}
