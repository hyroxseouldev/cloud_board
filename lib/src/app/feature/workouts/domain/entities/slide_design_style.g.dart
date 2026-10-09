// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slide_design_style.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SlideDesignStyle _$SlideDesignStyleFromJson(Map<String, dynamic> json) =>
    _SlideDesignStyle(
      version: (json['version'] as num?)?.toInt() ?? 1,
      family: json['family'] as String? ?? 'banner',
      fontFamily: json['fontFamily'] as String? ?? 'sans',
      titleColor: (json['titleColor'] as num?)?.toInt(),
      titleWeight: (json['titleWeight'] as num?)?.toInt() ?? 900,
      motif: json['motif'] as String? ?? '',
      originalTemplate: json['originalTemplate'] as String?,
    );

Map<String, dynamic> _$SlideDesignStyleToJson(_SlideDesignStyle instance) =>
    <String, dynamic>{
      'version': instance.version,
      'family': instance.family,
      'fontFamily': instance.fontFamily,
      'titleColor': instance.titleColor,
      'titleWeight': instance.titleWeight,
      'motif': instance.motif,
      'originalTemplate': instance.originalTemplate,
    };
