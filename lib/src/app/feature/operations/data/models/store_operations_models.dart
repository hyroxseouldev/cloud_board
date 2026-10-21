import 'package:cloud_board/src/app/core/config/legacy_brand_defaults.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

part 'store_operations_models.g.dart';

@JsonSerializable()
class BrandTemplateModel {
  const BrandTemplateModel({
    required this.storeName,
    required this.standbyMessage,
    required this.logoUrl,
    required this.promotionImageUrls,
    required this.primaryColorValue,
    required this.blackScreenStartMinutes,
    required this.blackScreenEndMinutes,
    this.standbyFullscreen = true,
    this.standbyShowText = true,
    this.standbyTextColor = 0xFFFFFFFF,
    this.standbyTextPosition = 'bottomLeft',
    this.standbyBackgroundColor = 0xFF000000,
    this.promotionDurationMinutes = const [],
    this.standbyTransition = StandbyTransition.fade,
    this.standbyImageFit = StandbyImageFit.contain,
    this.showCloudBoardLogo = false,
  });

  @JsonKey(defaultValue: LegacyBrandDefaults.storeName)
  final String storeName;
  final bool standbyFullscreen;
  final bool standbyShowText;
  final int standbyTextColor;
  final String standbyTextPosition;
  final int standbyBackgroundColor;

  @JsonKey(defaultValue: '다음 수업을 준비하고 있습니다')
  final String standbyMessage;
  final String? logoUrl;
  final bool showCloudBoardLogo;
  @JsonKey(defaultValue: <String>[])
  final List<String> promotionImageUrls;
  @JsonKey(defaultValue: <int>[])
  final List<int> promotionDurationMinutes;
  @JsonKey(
    defaultValue: StandbyTransition.fade,
    unknownEnumValue: StandbyTransition.fade,
  )
  final StandbyTransition standbyTransition;
  @JsonKey(
    defaultValue: StandbyImageFit.contain,
    unknownEnumValue: StandbyImageFit.contain,
  )
  final StandbyImageFit standbyImageFit;
  @JsonKey(defaultValue: 0xFF0B50FF)
  final int primaryColorValue;
  @JsonKey(defaultValue: 0)
  final int blackScreenStartMinutes;
  @JsonKey(defaultValue: 0)
  final int blackScreenEndMinutes;

  factory BrandTemplateModel.fromJson(Map<String, dynamic> json) =>
      _$BrandTemplateModelFromJson(json);

  factory BrandTemplateModel.fromEntity(BrandTemplate entity) =>
      BrandTemplateModel(
        storeName: entity.storeName,
        standbyFullscreen: entity.standbyFullscreen,
        standbyShowText: entity.standbyShowText,
        standbyTextColor: entity.standbyTextColor,
        standbyTextPosition: entity.standbyTextPosition,
        standbyBackgroundColor: entity.standbyBackgroundColor,

        standbyMessage: entity.standbyMessage,
        logoUrl: entity.logoUrl,
        showCloudBoardLogo: entity.showCloudBoardLogo,
        promotionImageUrls: entity.promotionImageUrls,
        promotionDurationMinutes: entity.promotionDurationMinutes,
        standbyTransition: entity.standbyTransition,
        standbyImageFit: entity.standbyImageFit,
        primaryColorValue: entity.primaryColorValue,
        blackScreenStartMinutes: entity.blackScreenStartMinutes,
        blackScreenEndMinutes: entity.blackScreenEndMinutes,
      );

  Map<String, dynamic> toJson() => _$BrandTemplateModelToJson(this);

  BrandTemplate toEntity() => BrandTemplate(
    storeName: storeName,
    standbyFullscreen: standbyFullscreen,
    standbyShowText: standbyShowText,
    standbyTextColor: standbyTextColor,
    standbyTextPosition:
        const ['topLeft', 'center', 'bottomLeft'].contains(standbyTextPosition)
        ? standbyTextPosition
        : 'bottomLeft',
    standbyBackgroundColor: standbyBackgroundColor,

    standbyMessage: standbyMessage,
    logoUrl: logoUrl,
    showCloudBoardLogo: showCloudBoardLogo,
    promotionImageUrls: promotionImageUrls,
    promotionDurationMinutes: promotionDurationMinutes,
    standbyTransition: standbyTransition,
    standbyImageFit: standbyImageFit,
    primaryColorValue: primaryColorValue,
    blackScreenStartMinutes: blackScreenStartMinutes,
    blackScreenEndMinutes: blackScreenEndMinutes,
  );
}

@JsonSerializable()
class WorkoutScheduleModel {
  const WorkoutScheduleModel({
    required this.id,
    required this.workoutId,
    required this.workoutName,
    required this.weekdays,
    required this.hour,
    required this.minute,
    required this.targetDeviceIds,
    required this.enabled,
    required this.lastOccurrenceKey,
    required this.createdAtMs,
  });

  final String id;
  final String workoutId;
  final String workoutName;
  @JsonKey(defaultValue: <int>[])
  final List<int> weekdays;
  final int hour;
  final int minute;
  @JsonKey(defaultValue: <String>[])
  final List<String> targetDeviceIds;
  @JsonKey(defaultValue: true)
  final bool enabled;
  final String? lastOccurrenceKey;
  final int createdAtMs;

  factory WorkoutScheduleModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutScheduleModelFromJson(json);

  factory WorkoutScheduleModel.fromEntity(WorkoutSchedule entity) =>
      WorkoutScheduleModel(
        id: entity.id,
        workoutId: entity.workoutId,
        workoutName: entity.workoutName,
        weekdays: entity.weekdays,
        hour: entity.hour,
        minute: entity.minute,
        targetDeviceIds: entity.targetDeviceIds,
        enabled: entity.enabled,
        lastOccurrenceKey: entity.lastOccurrenceKey,
        createdAtMs: entity.createdAtMs,
      );

  Map<String, dynamic> toJson() => _$WorkoutScheduleModelToJson(this);

  WorkoutSchedule toEntity() => WorkoutSchedule(
    id: id,
    workoutId: workoutId,
    workoutName: workoutName,
    weekdays: weekdays,
    hour: hour,
    minute: minute,
    targetDeviceIds: targetDeviceIds,
    enabled: enabled,
    lastOccurrenceKey: lastOccurrenceKey,
    createdAtMs: createdAtMs,
  );
}

@JsonSerializable()
class OperationEventModel {
  const OperationEventModel({
    required this.id,
    required this.type,
    required this.occurredAtMs,
    this.deviceId,
    this.workoutId,
    this.workoutName,
    this.scheduled = false,
    this.scheduledAtMs,
    this.sessionId,
    this.eventId,
    this.deviceName,
    this.zoneName,
    this.deviceRole,
    this.appVersion,
    this.phase,
    this.errorId,
    this.errorCode,
    this.incidentId,
    this.recoveryOfEventId,
    this.playbackImpact,
    this.connected,
    this.targetDeviceIds = const [],
    this.targetDeviceNames = const {},
    this.targetDeviceVersions = const {},
    this.schemaVersion = 1,
  });

  final String id, type;
  final int occurredAtMs;
  final String? deviceId, workoutId, workoutName;
  final bool scheduled;
  final int? scheduledAtMs;
  final String? sessionId,
      eventId,
      deviceName,
      zoneName,
      deviceRole,
      appVersion;
  final String? phase, errorId, errorCode, incidentId, recoveryOfEventId;
  final String? playbackImpact;
  final bool? connected;
  final List<String> targetDeviceIds;
  final Map<String, String> targetDeviceNames, targetDeviceVersions;
  final int schemaVersion;

  factory OperationEventModel.fromJson(Map<String, dynamic> json) =>
      _$OperationEventModelFromJson(json);

  Map<String, dynamic> toJson() => _$OperationEventModelToJson(this);

  factory OperationEventModel.fromEntity(OperationEvent event) =>
      OperationEventModel(
        id: event.id,
        type: event.type,
        occurredAtMs: event.occurredAtMs,
        deviceId: event.deviceId,
        workoutId: event.workoutId,
        workoutName: event.workoutName,
        scheduled: event.scheduled,
        scheduledAtMs: event.scheduledAtMs,
        sessionId: event.sessionId,
        eventId: event.eventId,
        deviceName: event.deviceName,
        zoneName: event.zoneName,
        deviceRole: event.deviceRole,
        appVersion: event.appVersion,
        phase: event.phase,
        errorId: event.errorId,
        errorCode: event.errorCode,
        incidentId: event.incidentId,
        recoveryOfEventId: event.recoveryOfEventId,
        playbackImpact: event.playbackImpact,
        connected: event.connected,
        targetDeviceIds: event.targetDeviceIds,
        targetDeviceNames: event.targetDeviceNames,
        targetDeviceVersions: event.targetDeviceVersions,
        schemaVersion: event.schemaVersion,
      );

  OperationEvent toEntity() => OperationEvent(
    id: id,
    type: type,
    occurredAtMs: occurredAtMs,
    deviceId: deviceId,
    workoutId: workoutId,
    workoutName: workoutName,
    scheduled: scheduled,
    scheduledAtMs: scheduledAtMs,
    sessionId: sessionId,
    eventId: eventId,
    deviceName: deviceName,
    zoneName: zoneName,
    deviceRole: deviceRole,
    appVersion: appVersion,
    phase: phase,
    errorId: errorId,
    errorCode: errorCode,
    incidentId: incidentId,
    recoveryOfEventId: recoveryOfEventId,
    playbackImpact: playbackImpact,
    connected: connected,
    targetDeviceIds: targetDeviceIds,
    targetDeviceNames: targetDeviceNames,
    targetDeviceVersions: targetDeviceVersions,
    schemaVersion: schemaVersion,
  );
}
