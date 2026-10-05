import 'package:json_annotation/json_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
part 'ai_slides_model.g.dart';

@JsonSerializable(explicitToJson: true)
class AiSlidesModel {
  const AiSlidesModel({
    required this.premium,
    required this.enabled,
    required this.remaining,
    required this.limit,
    this.result,
    this.cached = false,
  });
  final bool premium, enabled, cached;
  final int remaining, limit;
  final AiSlidesContentModel? result;
  factory AiSlidesModel.fromJson(Map<String, dynamic> json) =>
      _$AiSlidesModelFromJson(json);
  Map<String, dynamic> toJson() => _$AiSlidesModelToJson(this);
  AiSlidesAccess toAccess() => AiSlidesAccess(
    premium: premium,
    enabled: enabled,
    remaining: remaining,
    limit: limit,
  );
  AiSlidesResult toResult() {
    final content = result;
    if (content == null ||
        content.slides.isEmpty ||
        content.slides.length > 6) {
      throw const AiSlidesFailure('슬라이드 응답을 읽지 못했습니다. 다시 시도해 주세요.');
    }
    return AiSlidesResult(
      slides: content.slides.map((s) => s.toEntity()).toList(),
      warnings: content.warnings,
      remaining: remaining,
      cached: cached,
    );
  }
}

@JsonSerializable(explicitToJson: true)
class AiSlidesContentModel {
  const AiSlidesContentModel({required this.slides, required this.warnings});
  final List<AiSlideModel> slides;
  final List<String> warnings;
  factory AiSlidesContentModel.fromJson(Map<String, dynamic> json) =>
      _$AiSlidesContentModelFromJson(json);
  Map<String, dynamic> toJson() => _$AiSlidesContentModelToJson(this);
}

@JsonSerializable()
class AiSlideModel {
  const AiSlideModel({
    required this.title,
    required this.layout,
    required this.lines,
    this.workSeconds,
    this.restSeconds,
    this.sets,
  });
  final String title, layout;
  final List<String> lines;
  final int? workSeconds, restSeconds, sets;
  factory AiSlideModel.fromJson(Map<String, dynamic> json) =>
      _$AiSlideModelFromJson(json);
  Map<String, dynamic> toJson() => _$AiSlideModelToJson(this);
  AiSlideDraft toEntity() => AiSlideDraft(
    title: title,
    layout: layout,
    lines: lines,
    workSeconds: workSeconds,
    restSeconds: restSeconds,
    sets: sets,
  );
}
