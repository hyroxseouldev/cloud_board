import 'package:json_annotation/json_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';

part 'playback_session_model.g.dart';

@JsonSerializable()
class PlaybackSessionModel {
  const PlaybackSessionModel({
    required this.id,
    required this.ownerId,
    required this.zoneId,
    required this.targetDeviceIds,
    required this.workoutSnapshot,
    required this.status,
    this.briefing = false,
    this.startDelayMs = 0,
    required this.stepIndex,
    required this.remainingMs,
    required this.anchorServerMs,
    required this.revision,
    required this.updatedByDeviceId,
  });

  final String id;
  final String ownerId;
  @JsonKey(defaultValue: 'main')
  final String zoneId;
  @JsonKey(defaultValue: <String>[])
  final List<String> targetDeviceIds;
  final Map<String, dynamic> workoutSnapshot;
  final String status;
  @JsonKey(defaultValue: false)
  final bool briefing;
  @JsonKey(defaultValue: 0)
  final int startDelayMs;
  final int stepIndex;
  final int remainingMs;
  final int anchorServerMs;
  final int revision;
  final String updatedByDeviceId;

  factory PlaybackSessionModel.fromJson(Map<String, dynamic> json) =>
      _$PlaybackSessionModelFromJson(json);

  Map<String, dynamic> toJson() => _$PlaybackSessionModelToJson(this);

  PlaybackSession toEntity() => PlaybackSession(
    id: id,
    ownerId: ownerId,
    zoneId: zoneId,
    targetDeviceIds: targetDeviceIds,
    workout: WorkoutModel.fromJson(workoutSnapshot).toEntity(),
    status: PlaybackStatus.values.firstWhere(
      (value) => value.name == status,
      orElse: () => PlaybackStatus.completed,
    ),
    stepIndex: stepIndex,
    briefing: briefing,
    startDelayMs: startDelayMs,
    remainingMs: remainingMs,
    anchorServerMs: anchorServerMs,
    revision: revision,
    updatedByDeviceId: updatedByDeviceId,
  );

  factory PlaybackSessionModel.fromWorkout({
    required String id,
    required String ownerId,
    required String zoneId,
    required List<String> targetDeviceIds,
    required Workout workout,
    required int stepIndex,
    required int durationMs,
    required String deviceId,
    bool briefing = false,
  }) {
    final snapshot = WorkoutModel.fromEntity(workout).toJson()
      ..['createdAt'] = workout.createdAt.toIso8601String()
      ..['updatedAt'] = workout.updatedAt.toIso8601String();
    return PlaybackSessionModel(
      id: id,
      ownerId: ownerId,
      zoneId: zoneId,
      targetDeviceIds: List.unmodifiable(targetDeviceIds),
      workoutSnapshot: snapshot,
      status: briefing
          ? PlaybackStatus.paused.name
          : PlaybackStatus.playing.name,
      briefing: briefing,
      stepIndex: stepIndex,
      remainingMs: durationMs,
      anchorServerMs: 0,
      revision: 1,
      updatedByDeviceId: deviceId,
    );
  }
}
