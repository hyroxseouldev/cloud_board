import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

part 'playback_session.freezed.dart';

enum PlaybackStatus { playing, paused, completed }

@freezed
abstract class PlaybackSession with _$PlaybackSession {
  const factory PlaybackSession({
    required String id,
    required String ownerId,
    required String zoneId,
    @Default(<String>[]) List<String> targetDeviceIds,
    required Workout workout,
    required PlaybackStatus status,
    @Default(false) bool briefing,
    @Default(0) int startDelayMs,
    required int stepIndex,
    required int remainingMs,
    required int anchorServerMs,
    required int revision,
    required String updatedByDeviceId,
  }) = _PlaybackSession;
}
