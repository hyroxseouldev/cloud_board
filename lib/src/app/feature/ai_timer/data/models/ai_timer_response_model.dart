import 'package:json_annotation/json_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_timer/domain/entities/ai_timer_result.dart';
part 'ai_timer_response_model.g.dart';

@JsonSerializable(createToJson: false)
class AiTimerResponseModel {
  const AiTimerResponseModel({
    required this.premium,
    required this.enabled,
    required this.remaining,
    required this.limit,
    required this.resetsAtMs,
    this.result,
    this.cached = false,
  });
  final bool premium, enabled, cached;
  final int remaining, limit, resetsAtMs;
  final AiTimerSuggestionModel? result;
  factory AiTimerResponseModel.fromJson(Map<String, dynamic> json) =>
      _$AiTimerResponseModelFromJson(json);
  AiTimerAccess toAccess() => AiTimerAccess(
    premium: premium,
    enabled: enabled,
    remaining: remaining,
    limit: limit,
    resetsAt: DateTime.fromMillisecondsSinceEpoch(resetsAtMs),
  );
  AiTimerSuggestion toSuggestion() {
    final value = result;
    if (value == null) throw const AiTimerFailure('인식 결과가 없습니다. 다시 시도해 주세요.');
    return AiTimerSuggestion(
      name: value.name,
      workSeconds: value.workSeconds,
      restSeconds: value.restSeconds,
      sets: value.sets,
      warnings: value.warnings,
      cached: cached,
      remaining: remaining,
    );
  }
}

@JsonSerializable(createToJson: false)
class AiTimerSuggestionModel {
  const AiTimerSuggestionModel({
    this.name,
    this.workSeconds,
    this.restSeconds,
    this.sets,
    this.warnings = const [],
  });
  final String? name;
  final int? workSeconds, restSeconds, sets;
  final List<String> warnings;
  factory AiTimerSuggestionModel.fromJson(Map<String, dynamic> json) =>
      _$AiTimerSuggestionModelFromJson(json);
}
