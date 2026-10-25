import 'dart:async';

import 'package:cloud_board/src/app/core/services/android_cue_audio.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_audio_cues.dart';

/// One foreground attachment; native owner checks also reject late async work.
class AndroidWorkoutCues {
  // A manual phase change has no advance notice. Give every remote Android
  // display the same short preparation window, measured from the server anchor
  // rather than from receipt or sound loading. The visual timeline is unchanged.
  static const commandStartLeadMs = 750;

  static bool _deferredStart(PlaybackAudioCue cue) =>
      !cue.countdown && cue.id.contains('/start/');

  // recentCommand still admits only commands first observed within 500 ms.
  // An already admitted start may survive a provider rebuild until its deadline.
  static bool isExplicitCuePending(PlaybackAudioCue cue, int serverNowMs) {
    final age = serverNowMs - cue.serverTimeMs;
    return age >= 0 &&
        (_deferredStart(cue) ? age < commandStartLeadMs : age <= 500);
  }

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
  PlaybackAudioCue? _commandStart;

  Future<void> start({PlaybackAudioCue? explicitCue}) async {
    try {
      if (explicitCue != null &&
          _deferredStart(explicitCue) &&
          isExplicitCuePending(explicitCue, nowMs() + offsetMs)) {
        _commandStart = PlaybackAudioCue(
          explicitCue.id,
          explicitCue.serverTimeMs + commandStartLeadMs,
          explicitCue.sound,
        );
      }
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
          !_deferredStart(explicitCue) &&
          isExplicitCuePending(explicitCue, nowMs() + offsetMs)) {
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
      final serverNow = nowMs() + offsetMs;
      final commandStart = _commandStart;
      final cues = [
        ...plan.upcoming(serverNow),
        if (commandStart != null && commandStart.serverTimeMs > serverNow)
          commandStart,
      ]..sort((a, b) => a.serverTimeMs.compareTo(b.serverTimeMs));
      await audio.replace(owner, [
        for (final cue in cues.take(32))
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
