import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';

part 'first_class_progress.freezed.dart';
part 'first_class_progress.g.dart';

enum FirstClassStep { center, workout, display, playback }

@freezed
abstract class FirstClassProgress with _$FirstClassProgress {
  const FirstClassProgress._();
  const factory FirstClassProgress({
    required String sessionId,
    @Default(false) bool dismissed,
    @Default(false) bool centerReady,
    String? savedWorkoutId,
    String? verifiedDeviceId,
    String? playedSessionId,
    String? rehearsedWorkoutId,
    @Default(<String>[]) List<String> events,
  }) = _FirstClassProgress;

  factory FirstClassProgress.fromJson(Map<String, dynamic> json) =>
      _$FirstClassProgressFromJson(json);

  bool done(FirstClassStep step) => switch (step) {
    FirstClassStep.center => centerReady,
    FirstClassStep.workout => savedWorkoutId != null,
    FirstClassStep.display => verifiedDeviceId != null,
    FirstClassStep.playback => playedSessionId != null,
  };
  int get completedCount => FirstClassStep.values.where(done).length;
  bool get complete => completedCount == FirstClassStep.values.length;

  FirstClassNext next({required bool onlineTv}) {
    if (playedSessionId != null) return FirstClassNext.repeat;
    if (savedWorkoutId == null) return FirstClassNext.explore;
    if (rehearsedWorkoutId != savedWorkoutId) return FirstClassNext.rehearse;
    if (!centerReady) return FirstClassNext.center;
    if (verifiedDeviceId == null || !onlineTv) return FirstClassNext.connect;
    return FirstClassNext.play;
  }
}

enum FirstClassNext { explore, rehearse, center, connect, play, repeat }

/// A pairing record/online bit is not evidence that a class reached the TV.
/// Require a playing session, an explicitly selected target and its current ACK.
bool hasFirstPlaybackAck(
  PlaybackSession session,
  List<DisplayDevice> devices,
) =>
    session.status == PlaybackStatus.playing &&
    !session.briefing &&
    session.workout.modules.isNotEmpty &&
    session.targetDeviceIds.isNotEmpty &&
    devices.any(
      (device) =>
          session.targetDeviceIds.contains(device.id) &&
          device.paired &&
          device.online &&
          device.displayState == 'auto' &&
          device.currentSessionId == session.id &&
          device.acknowledgedRevision >= session.revision,
    );
