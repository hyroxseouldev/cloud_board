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
  });

  @JsonKey(defaultValue: 'CloudBoard Studio')
  final String storeName;
  @JsonKey(defaultValue: '다음 수업을 준비하고 있습니다')
  final String standbyMessage;
  final String? logoUrl;
  @JsonKey(defaultValue: <String>[])
  final List<String> promotionImageUrls;
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
        standbyMessage: entity.standbyMessage,
        logoUrl: entity.logoUrl,
        promotionImageUrls: entity.promotionImageUrls,
        primaryColorValue: entity.primaryColorValue,
        blackScreenStartMinutes: entity.blackScreenStartMinutes,
        blackScreenEndMinutes: entity.blackScreenEndMinutes,
      );

  Map<String, dynamic> toJson() => _$BrandTemplateModelToJson(this);

  BrandTemplate toEntity() => BrandTemplate(
    storeName: storeName,
    standbyMessage: standbyMessage,
    logoUrl: logoUrl,
    promotionImageUrls: promotionImageUrls,
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

@JsonSerializable(createToJson: false)
class OperationEventModel {
  const OperationEventModel({
    required this.id,
    required this.type,
    required this.occurredAtMs,
    required this.deviceId,
    required this.workoutId,
    required this.workoutName,
    required this.scheduled,
    required this.scheduledAtMs,
  });

  final String id;
  final String type;
  final int occurredAtMs;
  final String? deviceId;
  final String? workoutId;
  final String? workoutName;
  @JsonKey(defaultValue: false)
  final bool scheduled;
  final int? scheduledAtMs;

  factory OperationEventModel.fromJson(Map<String, dynamic> json) =>
      _$OperationEventModelFromJson(json);

  OperationEvent toEntity() => OperationEvent(
    id: id,
    type: type,
    occurredAtMs: occurredAtMs,
    deviceId: deviceId,
    workoutId: workoutId,
    workoutName: workoutName,
    scheduled: scheduled,
    scheduledAtMs: scheduledAtMs,
  );
}
