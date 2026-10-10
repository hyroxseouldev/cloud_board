// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'first_class_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FirstClassProgress _$FirstClassProgressFromJson(Map<String, dynamic> json) =>
    _FirstClassProgress(
      sessionId: json['sessionId'] as String,
      dismissed: json['dismissed'] as bool? ?? false,
      centerReady: json['centerReady'] as bool? ?? false,
      savedWorkoutId: json['savedWorkoutId'] as String?,
      verifiedDeviceId: json['verifiedDeviceId'] as String?,
      playedSessionId: json['playedSessionId'] as String?,
      rehearsedWorkoutId: json['rehearsedWorkoutId'] as String?,
      events:
          (json['events'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$FirstClassProgressToJson(_FirstClassProgress instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'dismissed': instance.dismissed,
      'centerReady': instance.centerReady,
      'savedWorkoutId': instance.savedWorkoutId,
      'verifiedDeviceId': instance.verifiedDeviceId,
      'playedSessionId': instance.playedSessionId,
      'rehearsedWorkoutId': instance.rehearsedWorkoutId,
      'events': instance.events,
    };
