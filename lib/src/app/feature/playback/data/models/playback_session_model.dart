import 'package:json_annotation/json_annotation.dart';

import '../../../workouts/data/models/workout_model.dart';
import '../../../workouts/domain/entities/workout.dart';
import '../../domain/entities/playback_session.dart';

part 'playback_session_model.g.dart';

@JsonSerializable()
class PlaybackSessionModel {
  const PlaybackSessionModel({
    required this.id,
    required this.ownerId,
    required this.workoutSnapshot,
    required this.status,
    required this.stepIndex,
    required this.remainingMs,
    required this.anchorServerMs,
    required this.revision,
    required this.updatedByDeviceId,
  });

  final String id;
  final String ownerId;
  final Map<String, dynamic> workoutSnapshot;
  final String status;
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
    workout: WorkoutModel.fromJson(workoutSnapshot).toEntity(),
    status: PlaybackStatus.values.firstWhere(
      (value) => value.name == status,
      orElse: () => PlaybackStatus.completed,
    ),
    stepIndex: stepIndex,
    remainingMs: remainingMs,
    anchorServerMs: anchorServerMs,
    revision: revision,
    updatedByDeviceId: updatedByDeviceId,
  );

  factory PlaybackSessionModel.fromWorkout({
    required String id,
    required String ownerId,
    required Workout workout,
    required int stepIndex,
    required int durationMs,
    required String deviceId,
  }) {
    final snapshot = WorkoutModel.fromEntity(workout).toJson()
      ..['createdAt'] = workout.createdAt.toIso8601String()
      ..['updatedAt'] = workout.updatedAt.toIso8601String();
    return PlaybackSessionModel(
      id: id,
      ownerId: ownerId,
      workoutSnapshot: snapshot,
      status: PlaybackStatus.playing.name,
      stepIndex: stepIndex,
      remainingMs: durationMs,
      anchorServerMs: 0,
      revision: 1,
      updatedByDeviceId: deviceId,
    );
  }
}
