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
  zoneId: json['zoneId'] as String? ?? 'main',
  targetDeviceIds:
      (json['targetDeviceIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  workoutSnapshot: json['workoutSnapshot'] as Map<String, dynamic>,
  status: json['status'] as String,
  briefing: json['briefing'] as bool? ?? false,
  startDelayMs: (json['startDelayMs'] as num?)?.toInt() ?? 0,
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
  'zoneId': instance.zoneId,
  'targetDeviceIds': instance.targetDeviceIds,
  'workoutSnapshot': instance.workoutSnapshot,
  'status': instance.status,
  'briefing': instance.briefing,
  'startDelayMs': instance.startDelayMs,
  'stepIndex': instance.stepIndex,
  'remainingMs': instance.remainingMs,
  'anchorServerMs': instance.anchorServerMs,
  'revision': instance.revision,
  'updatedByDeviceId': instance.updatedByDeviceId,
};
