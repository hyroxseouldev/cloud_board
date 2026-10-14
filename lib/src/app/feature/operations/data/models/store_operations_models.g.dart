// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_operations_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrandTemplateModel _$BrandTemplateModelFromJson(
  Map<String, dynamic> json,
) => BrandTemplateModel(
  storeName: json['storeName'] as String? ?? 'CloudBoard Studio',
  standbyMessage: json['standbyMessage'] as String? ?? '다음 수업을 준비하고 있습니다',
  logoUrl: json['logoUrl'] as String?,
  promotionImageUrls:
      (json['promotionImageUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  primaryColorValue: (json['primaryColorValue'] as num?)?.toInt() ?? 4278931711,
  blackScreenStartMinutes:
      (json['blackScreenStartMinutes'] as num?)?.toInt() ?? 0,
  blackScreenEndMinutes: (json['blackScreenEndMinutes'] as num?)?.toInt() ?? 0,
  standbyFullscreen: json['standbyFullscreen'] as bool? ?? true,
  standbyShowText: json['standbyShowText'] as bool? ?? true,
  standbyTextColor: (json['standbyTextColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
  standbyTextPosition: json['standbyTextPosition'] as String? ?? 'bottomLeft',
  standbyBackgroundColor:
      (json['standbyBackgroundColor'] as num?)?.toInt() ?? 0xFF000000,
  promotionDurationMinutes:
      (json['promotionDurationMinutes'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      [],
  standbyTransition:
      $enumDecodeNullable(
        _$StandbyTransitionEnumMap,
        json['standbyTransition'],
        unknownValue: StandbyTransition.fade,
      ) ??
      StandbyTransition.fade,
  standbyImageFit:
      $enumDecodeNullable(
        _$StandbyImageFitEnumMap,
        json['standbyImageFit'],
        unknownValue: StandbyImageFit.contain,
      ) ??
      StandbyImageFit.contain,
  showCloudBoardLogo: json['showCloudBoardLogo'] as bool? ?? false,
);

Map<String, dynamic> _$BrandTemplateModelToJson(
  BrandTemplateModel instance,
) => <String, dynamic>{
  'storeName': instance.storeName,
  'standbyFullscreen': instance.standbyFullscreen,
  'standbyShowText': instance.standbyShowText,
  'standbyTextColor': instance.standbyTextColor,
  'standbyTextPosition': instance.standbyTextPosition,
  'standbyBackgroundColor': instance.standbyBackgroundColor,
  'standbyMessage': instance.standbyMessage,
  'logoUrl': instance.logoUrl,
  'showCloudBoardLogo': instance.showCloudBoardLogo,
  'promotionImageUrls': instance.promotionImageUrls,
  'promotionDurationMinutes': instance.promotionDurationMinutes,
  'standbyTransition': _$StandbyTransitionEnumMap[instance.standbyTransition]!,
  'standbyImageFit': _$StandbyImageFitEnumMap[instance.standbyImageFit]!,
  'primaryColorValue': instance.primaryColorValue,
  'blackScreenStartMinutes': instance.blackScreenStartMinutes,
  'blackScreenEndMinutes': instance.blackScreenEndMinutes,
};

const _$StandbyTransitionEnumMap = {
  StandbyTransition.none: 'none',
  StandbyTransition.fade: 'fade',
  StandbyTransition.slide: 'slide',
};

const _$StandbyImageFitEnumMap = {
  StandbyImageFit.contain: 'contain',
  StandbyImageFit.cover: 'cover',
};

WorkoutScheduleModel _$WorkoutScheduleModelFromJson(
  Map<String, dynamic> json,
) => WorkoutScheduleModel(
  id: json['id'] as String,
  workoutId: json['workoutId'] as String,
  workoutName: json['workoutName'] as String,
  weekdays:
      (json['weekdays'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      [],
  hour: (json['hour'] as num).toInt(),
  minute: (json['minute'] as num).toInt(),
  targetDeviceIds:
      (json['targetDeviceIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  enabled: json['enabled'] as bool? ?? true,
  lastOccurrenceKey: json['lastOccurrenceKey'] as String?,
  createdAtMs: (json['createdAtMs'] as num).toInt(),
);

Map<String, dynamic> _$WorkoutScheduleModelToJson(
  WorkoutScheduleModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'workoutId': instance.workoutId,
  'workoutName': instance.workoutName,
  'weekdays': instance.weekdays,
  'hour': instance.hour,
  'minute': instance.minute,
  'targetDeviceIds': instance.targetDeviceIds,
  'enabled': instance.enabled,
  'lastOccurrenceKey': instance.lastOccurrenceKey,
  'createdAtMs': instance.createdAtMs,
};

OperationEventModel _$OperationEventModelFromJson(Map<String, dynamic> json) =>
    OperationEventModel(
      id: json['id'] as String,
      type: json['type'] as String,
      occurredAtMs: (json['occurredAtMs'] as num).toInt(),
      deviceId: json['deviceId'] as String?,
      workoutId: json['workoutId'] as String?,
      workoutName: json['workoutName'] as String?,
      scheduled: json['scheduled'] as bool? ?? false,
      scheduledAtMs: (json['scheduledAtMs'] as num?)?.toInt(),
      sessionId: json['sessionId'] as String?,
      eventId: json['eventId'] as String?,
      deviceName: json['deviceName'] as String?,
      zoneName: json['zoneName'] as String?,
      deviceRole: json['deviceRole'] as String?,
      appVersion: json['appVersion'] as String?,
      phase: json['phase'] as String?,
      errorId: json['errorId'] as String?,
      errorCode: json['errorCode'] as String?,
      incidentId: json['incidentId'] as String?,
      recoveryOfEventId: json['recoveryOfEventId'] as String?,
      playbackImpact: json['playbackImpact'] as String?,
      targetDeviceIds:
          (json['targetDeviceIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      targetDeviceNames:
          (json['targetDeviceNames'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      targetDeviceVersions:
          (json['targetDeviceVersions'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$OperationEventModelToJson(
  OperationEventModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'occurredAtMs': instance.occurredAtMs,
  'deviceId': instance.deviceId,
  'workoutId': instance.workoutId,
  'workoutName': instance.workoutName,
  'scheduled': instance.scheduled,
  'scheduledAtMs': instance.scheduledAtMs,
  'sessionId': instance.sessionId,
  'eventId': instance.eventId,
  'deviceName': instance.deviceName,
  'zoneName': instance.zoneName,
  'deviceRole': instance.deviceRole,
  'appVersion': instance.appVersion,
  'phase': instance.phase,
  'errorId': instance.errorId,
  'errorCode': instance.errorCode,
  'incidentId': instance.incidentId,
  'recoveryOfEventId': instance.recoveryOfEventId,
  'playbackImpact': instance.playbackImpact,
  'targetDeviceIds': instance.targetDeviceIds,
  'targetDeviceNames': instance.targetDeviceNames,
  'targetDeviceVersions': instance.targetDeviceVersions,
  'schemaVersion': instance.schemaVersion,
};
