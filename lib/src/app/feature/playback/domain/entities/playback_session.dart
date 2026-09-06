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
    required Workout workout,
    required PlaybackStatus status,
    required int stepIndex,
    required int remainingMs,
    required int anchorServerMs,
    required int revision,
    required String updatedByDeviceId,
  }) = _PlaybackSession;
}
