// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_timer_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiTimerResponseModel _$AiTimerResponseModelFromJson(
  Map<String, dynamic> json,
) => AiTimerResponseModel(
  premium: json['premium'] as bool,
  enabled: json['enabled'] as bool,
  remaining: (json['remaining'] as num).toInt(),
  limit: (json['limit'] as num).toInt(),
  resetsAtMs: (json['resetsAtMs'] as num).toInt(),
  result: json['result'] == null
      ? null
      : AiTimerSuggestionModel.fromJson(json['result'] as Map<String, dynamic>),
  cached: json['cached'] as bool? ?? false,
);

AiTimerSuggestionModel _$AiTimerSuggestionModelFromJson(
  Map<String, dynamic> json,
) => AiTimerSuggestionModel(
  name: json['name'] as String?,
  workSeconds: (json['workSeconds'] as num?)?.toInt(),
  restSeconds: (json['restSeconds'] as num?)?.toInt(),
  sets: (json['sets'] as num?)?.toInt(),
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);
