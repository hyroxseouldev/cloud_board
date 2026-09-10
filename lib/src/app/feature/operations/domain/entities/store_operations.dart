import 'package:freezed_annotation/freezed_annotation.dart';

part 'store_operations.freezed.dart';

enum RemoteDisplayState { auto, standby, black }

enum StandbyTransition { none, fade, slide }

enum StandbyImageFit { contain, cover }

@freezed
abstract class BrandTemplate with _$BrandTemplate {
  const factory BrandTemplate({
    required String storeName,
    required String standbyMessage,
    required String? logoUrl,
    required List<String> promotionImageUrls,
    required int primaryColorValue,
    required int blackScreenStartMinutes,
    required int blackScreenEndMinutes,
    @Default(<int>[]) List<int> promotionDurationMinutes,
    @Default(StandbyTransition.fade) StandbyTransition standbyTransition,
    @Default(StandbyImageFit.contain) StandbyImageFit standbyImageFit,
  }) = _BrandTemplate;

  factory BrandTemplate.initial() => const BrandTemplate(
    storeName: 'CloudBoard Studio',
    standbyMessage: '다음 수업을 준비하고 있습니다',
    logoUrl: null,
    promotionImageUrls: <String>[],
    primaryColorValue: 0xFF0B50FF,
    blackScreenStartMinutes: 0,
    blackScreenEndMinutes: 0,
  );
}

@freezed
abstract class WorkoutSchedule with _$WorkoutSchedule {
  const factory WorkoutSchedule({
    required String id,
    required String workoutId,
    required String workoutName,
    required List<int> weekdays,
    required int hour,
    required int minute,
    required List<String> targetDeviceIds,
    required bool enabled,
    required String? lastOccurrenceKey,
    required int createdAtMs,
  }) = _WorkoutSchedule;
}

@freezed
abstract class OperationEvent with _$OperationEvent {
  const factory OperationEvent({
    required String id,
    required String type,
    required int occurredAtMs,
    required String? deviceId,
    required String? workoutId,
    required String? workoutName,
    required bool scheduled,
    required int? scheduledAtMs,
  }) = _OperationEvent;
}

@freezed
abstract class OperationsReport with _$OperationsReport {
  const factory OperationsReport({
    required int todayPlaybackCount,
    required int monthPlaybackCount,
    required int scheduledPlaybackCount,
    required int onTimePlaybackCount,
    required int disconnectCount,
    required Duration onlineDuration,
    required String? mostPlayedWorkoutName,
    required int mostPlayedWorkoutCount,
  }) = _OperationsReport;
}
