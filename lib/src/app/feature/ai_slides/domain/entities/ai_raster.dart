// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
part 'ai_raster.freezed.dart';
part 'ai_raster.g.dart';

@freezed
abstract class AiRasterGroup with _$AiRasterGroup {
  const factory AiRasterGroup({
    required String heading,
    required List<String> lines,
  }) = _AiRasterGroup;
  factory AiRasterGroup.fromJson(Map<String, dynamic> json) =>
      _$AiRasterGroupFromJson(json);
}

@freezed
abstract class AiRasterDraft with _$AiRasterDraft {
  @JsonSerializable(explicitToJson: true)
  const factory AiRasterDraft({
    @Default('') String rawWod,
    @Default('오늘의 수업') String title,
    @Default('') String brief,
    @Default(42) double bodyFontSize,
    @Default([]) List<AiRasterGroup> groups,
  }) = _AiRasterDraft;
  factory AiRasterDraft.fromJson(Map<String, dynamic> json) =>
      _$AiRasterDraftFromJson(json);
}

@freezed
abstract class AiRasterAsset with _$AiRasterAsset {
  const factory AiRasterAsset({
    required String sha256,
    required int width,
    required int height,
    @Default([]) List<double> sourceRect,
  }) = _AiRasterAsset;
  factory AiRasterAsset.fromJson(Map<String, dynamic> json) =>
      _$AiRasterAssetFromJson(json);
}

@freezed
abstract class AiRasterBrand with _$AiRasterBrand {
  @JsonSerializable(explicitToJson: true)
  const factory AiRasterBrand({
    required String key,
    required int revision,
    required int catalogRevision,
    required int recipeRevision,
    required String templateId,
    required String name,
    required AiRasterAsset reference,
    required AiRasterAsset logo,
    required String backgroundColor,
    required String textColor,
    required String accentColor,
  }) = _AiRasterBrand;
  factory AiRasterBrand.fromJson(Map<String, dynamic> json) =>
      _$AiRasterBrandFromJson(json);
}

@freezed
abstract class AiRasterJob with _$AiRasterJob {
  @JsonSerializable(explicitToJson: true)
  const factory AiRasterJob({
    required String requestId,
    required String status,
    required String brandKey,
    required AiRasterDraft draft,
    AiRasterAsset? artifact,
    int? expiresAtMs,
    String? message,
  }) = _AiRasterJob;
  factory AiRasterJob.fromJson(Map<String, dynamic> json) =>
      _$AiRasterJobFromJson(json);
}

@freezed
abstract class AiRasterState with _$AiRasterState {
  const factory AiRasterState({
    @Default(true) bool loading,
    @Default(false) bool busy,
    @Default(false) bool allowed,
    @Default(false) bool enabled,
    @Default(0) int remaining,
    @Default(0) int limit,
    @Default(AiRasterDraft()) AiRasterDraft draft,
    AiRasterBrand? brand,
    AiRasterJob? result,
    @Default([]) List<AiRasterJob> history,
    String? pendingRequestId,
    String? pendingStatus,
    String? error,
  }) = _AiRasterState;
}

List<String> rasterSourceLines(String raw) => raw
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

String? rasterDraftError(AiRasterDraft draft) {
  final lines = rasterSourceLines(draft.rawWod);
  if (lines.isEmpty ||
      draft.rawWod.length > 6000 ||
      lines.length > 60 ||
      lines.any((line) => line.length > 300) ||
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(draft.rawWod)) {
    return '수업 원문은 6,000자·60줄 이내, 각 줄은 300자 이내로 입력해 주세요.';
  }
  if (draft.title.trim().isEmpty ||
      draft.title.length > 60 ||
      draft.brief.length > 1000 ||
      ![32, 38, 42].contains(draft.bodyFontSize)) {
    return '제목은 1~60자, 요청은 1,000자 이내로 입력하고 글자 크기를 확인해 주세요.';
  }
  if (draft.groups.isEmpty ||
      draft.groups.length > 3 ||
      draft.groups.any(
        (group) => group.lines.isEmpty || group.heading.length > 60,
      )) {
    return '1~3개 그룹으로 나눠 주세요.';
  }
  final grouped = draft.groups.expand((group) => group.lines).toList();
  if (grouped.length != lines.length ||
      lines.indexed.any((entry) => entry.$2 != grouped[entry.$1])) {
    return '원문 운동·숫자·단위와 순서를 유지해 주세요.';
  }
  return null;
}
