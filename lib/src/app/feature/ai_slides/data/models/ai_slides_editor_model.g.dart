// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_slides_editor_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiSlidesSavedDraftModel _$AiSlidesSavedDraftModelFromJson(
  Map<String, dynamic> json,
) => AiSlidesSavedDraftModel(
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
  prompt: json['prompt'] as String,
  generatedPrompt: json['generatedPrompt'] as String?,
  draft: json['draft'] == null
      ? null
      : AiSlideDraftModel.fromJson(json['draft'] as Map<String, dynamic>),
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$AiSlidesSavedDraftModelToJson(
  AiSlidesSavedDraftModel instance,
) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'prompt': instance.prompt,
  'generatedPrompt': instance.generatedPrompt,
  'draft': instance.draft?.toJson(),
  'warnings': instance.warnings,
};

AiSlideDraftModel _$AiSlideDraftModelFromJson(Map<String, dynamic> json) =>
    AiSlideDraftModel(
      title: json['title'] as String,
      layout: json['layout'] as String,
      lines: (json['lines'] as List<dynamic>).map((e) => e as String).toList(),
      designBackgroundColor: (json['designBackgroundColor'] as num?)?.toInt(),
      designTextColor: (json['designTextColor'] as num?)?.toInt(),
      designAccentColor: (json['designAccentColor'] as num?)?.toInt(),
      workSeconds: (json['workSeconds'] as num?)?.toInt(),
      restSeconds: (json['restSeconds'] as num?)?.toInt(),
      sets: (json['sets'] as num?)?.toInt(),
      designLayout: json['designLayout'] as String? ?? 'auto',
      designFontWeight: (json['designFontWeight'] as num?)?.toInt() ?? 900,
      designItalic: json['designItalic'] as bool? ?? true,
      designSpacing: (json['designSpacing'] as num?)?.toDouble() ?? 1.0,
      showTimer: json['showTimer'] as bool? ?? true,
      timerX: (json['timerX'] as num?)?.toDouble() ?? 0.84,
      timerY: (json['timerY'] as num?)?.toDouble() ?? 0.5,
      timerSize: (json['timerSize'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$AiSlideDraftModelToJson(AiSlideDraftModel instance) =>
    <String, dynamic>{
      'title': instance.title,
      'layout': instance.layout,
      'lines': instance.lines,
      'designBackgroundColor': instance.designBackgroundColor,
      'designTextColor': instance.designTextColor,
      'designAccentColor': instance.designAccentColor,
      'workSeconds': instance.workSeconds,
      'restSeconds': instance.restSeconds,
      'sets': instance.sets,
      'designLayout': instance.designLayout,
      'designFontWeight': instance.designFontWeight,
      'designItalic': instance.designItalic,
      'showTimer': instance.showTimer,
      'designSpacing': instance.designSpacing,
      'timerX': instance.timerX,
      'timerY': instance.timerY,
      'timerSize': instance.timerSize,
    };

AiSlideThemeModel _$AiSlideThemeModelFromJson(Map<String, dynamic> json) =>
    AiSlideThemeModel(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      designBackgroundColor: (json['designBackgroundColor'] as num?)?.toInt(),
      designTextColor: (json['designTextColor'] as num?)?.toInt(),
      designAccentColor: (json['designAccentColor'] as num?)?.toInt(),
      designLayout: json['designLayout'] as String? ?? 'auto',
      designFontWeight: (json['designFontWeight'] as num?)?.toInt() ?? 900,
      designItalic: json['designItalic'] as bool? ?? true,
      designSpacing: (json['designSpacing'] as num?)?.toDouble() ?? 1.0,
      showTimer: json['showTimer'] as bool? ?? true,
      timerX: (json['timerX'] as num?)?.toDouble() ?? 0.84,
      timerY: (json['timerY'] as num?)?.toDouble() ?? 0.5,
      timerSize: (json['timerSize'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$AiSlideThemeModelToJson(AiSlideThemeModel instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'designBackgroundColor': instance.designBackgroundColor,
      'designTextColor': instance.designTextColor,
      'designAccentColor': instance.designAccentColor,
      'designLayout': instance.designLayout,
      'designFontWeight': instance.designFontWeight,
      'designItalic': instance.designItalic,
      'showTimer': instance.showTimer,
      'designSpacing': instance.designSpacing,
      'timerX': instance.timerX,
      'timerY': instance.timerY,
      'timerSize': instance.timerSize,
    };
