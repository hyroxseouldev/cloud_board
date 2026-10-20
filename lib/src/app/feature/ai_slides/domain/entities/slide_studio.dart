import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

part 'slide_studio.freezed.dart';

enum StudioMode { template, organize, style, artwork }

@freezed
abstract class StudioInput with _$StudioInput {
  const factory StudioInput({
    required AiSlideDesign design,
    @Default('') String raw,
    @Default('오늘의 수업') String title,
    @Default('') String subtitle,
    @Default('') String brief,
    @Default(StudioMode.template) StudioMode mode,
    @Default(1) int artworkGroups,
    @Default(42) double artworkFontSize,
    String? referenceHash,
  }) = _StudioInput;
}

@freezed
abstract class StudioUsage with _$StudioUsage {
  const factory StudioUsage({
    required bool allowed,
    required bool enabled,
    required int used,
    int? remaining,
    int? limit,
    @Default(false) bool unlimited,
    @Default(false) bool tokenContractAvailable,
    int? lastInputTokens,
    int? lastOutputTokens,
    String? lastRequestId,
    DateTime? resetsAt,
    String? availabilityReason,
  }) = _StudioUsage;
}

@freezed
abstract class StudioOperation with _$StudioOperation {
  const factory StudioOperation({
    required String requestId,
    required String status,
    @Default([]) List<AiRasterGroup> groups,
    @Default([]) List<AiSlideDesign> designs,
    @Default([]) List<String> warnings,
    String? message,
  }) = _StudioOperation;
}

@freezed
abstract class StudioResult with _$StudioResult {
  const factory StudioResult({
    required String id,
    required StudioInput input,
    Uint8List? reference,
    AiSlideDraft? draft,
    AiRasterBrand? brand,
    AiRasterJob? job,
    WorkoutModule? savedModule,
    @Default([]) List<String> warnings,
  }) = _StudioResult;
}

@freezed
abstract class SlideStudioState with _$SlideStudioState {
  const SlideStudioState._();
  const factory SlideStudioState({
    required StudioInput input,
    Uint8List? reference,
    @Default(false) bool busy,
    @Default(false) bool saving,
    @Default(true) bool usageLoading,
    StudioUsage? usage,
    String? usageError,
    AiRasterBrand? brand,
    String? brandError,
    StudioResult? result,
    @Default([]) List<StudioResult> history,
    @Default([]) List<AiSlideDesign> proposals,
    String? pendingId,
    StudioInput? pendingInput,
    StudioOperation? completedOperation,
    @Default(false) bool pendingRaster,
    String? error,
    @Default(false) bool leaving,
  }) = _SlideStudioState;

  bool get dirty => result != null && result!.input != input;
  bool get unsaved =>
      !leaving &&
      (busy ||
          pendingId != null ||
          dirty ||
          result?.savedModule == null &&
              (input.raw.isNotEmpty ||
                  input.brief.isNotEmpty ||
                  reference != null ||
                  result != null));
}
