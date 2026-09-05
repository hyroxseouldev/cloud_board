// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_session_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlaybackSessionModel _$PlaybackSessionModelFromJson(
  Map<String, dynamic> json,
) => PlaybackSessionModel(
  id: json['id'] as String,
  ownerId: json['ownerId'] as String,
  workoutSnapshot: json['workoutSnapshot'] as Map<String, dynamic>,
  status: json['status'] as String,
  stepIndex: (json['stepIndex'] as num).toInt(),
  remainingMs: (json['remainingMs'] as num).toInt(),
  anchorServerMs: (json['anchorServerMs'] as num).toInt(),
  revision: (json['revision'] as num).toInt(),
  updatedByDeviceId: json['updatedByDeviceId'] as String,
);

Map<String, dynamic> _$PlaybackSessionModelToJson(
  PlaybackSessionModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'ownerId': instance.ownerId,
  'workoutSnapshot': instance.workoutSnapshot,
  'status': instance.status,
  'stepIndex': instance.stepIndex,
  'remainingMs': instance.remainingMs,
  'anchorServerMs': instance.anchorServerMs,
  'revision': instance.revision,
  'updatedByDeviceId': instance.updatedByDeviceId,
};
