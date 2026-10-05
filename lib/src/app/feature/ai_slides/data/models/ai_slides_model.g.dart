// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_slides_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiSlidesModel _$AiSlidesModelFromJson(Map<String, dynamic> json) =>
    AiSlidesModel(
      premium: json['premium'] as bool,
      enabled: json['enabled'] as bool,
      remaining: (json['remaining'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      result: json['result'] == null
          ? null
          : AiSlidesContentModel.fromJson(
              json['result'] as Map<String, dynamic>,
            ),
      cached: json['cached'] as bool? ?? false,
    );

Map<String, dynamic> _$AiSlidesModelToJson(AiSlidesModel instance) =>
    <String, dynamic>{
      'premium': instance.premium,
      'enabled': instance.enabled,
      'cached': instance.cached,
      'remaining': instance.remaining,
      'limit': instance.limit,
      'result': instance.result?.toJson(),
    };

AiSlidesContentModel _$AiSlidesContentModelFromJson(
  Map<String, dynamic> json,
) => AiSlidesContentModel(
  slides: (json['slides'] as List<dynamic>)
      .map((e) => AiSlideModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  warnings: (json['warnings'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$AiSlidesContentModelToJson(
  AiSlidesContentModel instance,
) => <String, dynamic>{
  'slides': instance.slides.map((e) => e.toJson()).toList(),
  'warnings': instance.warnings,
};

AiSlideModel _$AiSlideModelFromJson(Map<String, dynamic> json) => AiSlideModel(
  title: json['title'] as String,
  layout: json['layout'] as String,
  lines: (json['lines'] as List<dynamic>).map((e) => e as String).toList(),
  sections: (json['sections'] as List<dynamic>?)
      ?.map((e) => AiSlideSectionModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  workSeconds: (json['workSeconds'] as num?)?.toInt(),
  restSeconds: (json['restSeconds'] as num?)?.toInt(),
  sets: (json['sets'] as num?)?.toInt(),
);

Map<String, dynamic> _$AiSlideModelToJson(AiSlideModel instance) =>
    <String, dynamic>{
      'title': instance.title,
      'layout': instance.layout,
      'lines': instance.lines,
      'sections': instance.sections?.map((e) => e.toJson()).toList(),
      'workSeconds': instance.workSeconds,
      'restSeconds': instance.restSeconds,
      'sets': instance.sets,
    };

AiSlideSectionModel _$AiSlideSectionModelFromJson(Map<String, dynamic> json) =>
    AiSlideSectionModel(
      heading: json['heading'] as String,
      lines: (json['lines'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$AiSlideSectionModelToJson(
  AiSlideSectionModel instance,
) => <String, dynamic>{'heading': instance.heading, 'lines': instance.lines};
