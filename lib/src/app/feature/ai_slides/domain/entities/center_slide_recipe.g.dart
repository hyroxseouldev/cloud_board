// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'center_slide_recipe.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CenterSlideRecipe _$CenterSlideRecipeFromJson(Map<String, dynamic> json) =>
    _CenterSlideRecipe(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      templateId: json['templateId'] as String,
      revision: (json['revision'] as num).toInt(),
      centerId: json['centerId'] as String,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      backgroundColor: (json['backgroundColor'] as num).toInt(),
      backgroundPath: json['backgroundPath'] as String?,
      backgroundSha256: json['backgroundSha256'] as String?,
      fields: (json['fields'] as List<dynamic>)
          .map((e) => CenterSlideField.fromJson(e as Map<String, dynamic>))
          .toList(),
      body: json['body'] == null
          ? null
          : CenterSlideBody.fromJson(json['body'] as Map<String, dynamic>),
      thumbnail: json['thumbnail'] == null
          ? null
          : CenterSlideThumbnail.fromJson(
              json['thumbnail'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$CenterSlideRecipeToJson(_CenterSlideRecipe instance) =>
    <String, dynamic>{
      'schemaVersion': instance.schemaVersion,
      'templateId': instance.templateId,
      'revision': instance.revision,
      'centerId': instance.centerId,
      'width': instance.width,
      'height': instance.height,
      'backgroundColor': instance.backgroundColor,
      'backgroundPath': instance.backgroundPath,
      'backgroundSha256': instance.backgroundSha256,
      'fields': instance.fields.map((e) => e.toJson()).toList(),
      'body': instance.body?.toJson(),
      'thumbnail': ?instance.thumbnail?.toJson(),
    };

_CenterSlideBody _$CenterSlideBodyFromJson(Map<String, dynamic> json) =>
    _CenterSlideBody(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      fontSize: (json['fontSize'] as num).toDouble(),
      color: (json['color'] as num).toInt(),
      headingColor: (json['headingColor'] as num).toInt(),
      fontFamily: json['fontFamily'] as String,
      fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 600,
      layout: json['layout'] as String? ?? 'auto',
      maxColumns: (json['maxColumns'] as num?)?.toInt() ?? 3,
    );

Map<String, dynamic> _$CenterSlideBodyToJson(_CenterSlideBody instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
      'fontSize': instance.fontSize,
      'color': instance.color,
      'headingColor': instance.headingColor,
      'fontFamily': instance.fontFamily,
      'fontWeight': instance.fontWeight,
      'layout': instance.layout,
      'maxColumns': instance.maxColumns,
    };

_CenterSlideField _$CenterSlideFieldFromJson(Map<String, dynamic> json) =>
    _CenterSlideField(
      binding: json['binding'] as String,
      lineIndex: (json['lineIndex'] as num?)?.toInt(),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      fontSize: (json['fontSize'] as num).toDouble(),
      color: (json['color'] as num).toInt(),
      fontFamily: json['fontFamily'] as String,
      fontWeight: (json['fontWeight'] as num).toInt(),
      italic: json['italic'] as bool? ?? false,
      align: json['align'] as String? ?? 'left',
      originalText: json['originalText'] as String?,
      clearColor: (json['clearColor'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CenterSlideFieldToJson(_CenterSlideField instance) =>
    <String, dynamic>{
      'binding': instance.binding,
      'lineIndex': instance.lineIndex,
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
      'fontSize': instance.fontSize,
      'color': instance.color,
      'fontFamily': instance.fontFamily,
      'fontWeight': instance.fontWeight,
      'italic': instance.italic,
      'align': instance.align,
      'originalText': instance.originalText,
      'clearColor': instance.clearColor,
    };

_CenterSlideThumbnail _$CenterSlideThumbnailFromJson(
  Map<String, dynamic> json,
) => _CenterSlideThumbnail(
  path: json['path'] as String,
  sha256: json['sha256'] as String,
  revision: (json['revision'] as num).toInt(),
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
);

Map<String, dynamic> _$CenterSlideThumbnailToJson(
  _CenterSlideThumbnail instance,
) => <String, dynamic>{
  'path': instance.path,
  'sha256': instance.sha256,
  'revision': instance.revision,
  'width': instance.width,
  'height': instance.height,
};
