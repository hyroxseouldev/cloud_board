// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_slide_design_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiSlideDesignModel _$AiSlideDesignModelFromJson(Map<String, dynamic> json) =>
    AiSlideDesignModel(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      theme: AiSlideThemeModel.fromJson(json['theme'] as Map<String, dynamic>),
      storeId: json['storeId'] as String?,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$AiSlideDesignModelToJson(AiSlideDesignModel instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'name': instance.name,
      'description': instance.description,
      'storeId': instance.storeId,
      'theme': instance.theme.toJson(),
    };
