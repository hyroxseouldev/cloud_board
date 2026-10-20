// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_raster.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AiRasterGroup _$AiRasterGroupFromJson(Map<String, dynamic> json) =>
    _AiRasterGroup(
      heading: json['heading'] as String,
      lines: (json['lines'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$AiRasterGroupToJson(_AiRasterGroup instance) =>
    <String, dynamic>{'heading': instance.heading, 'lines': instance.lines};

_AiRasterDraft _$AiRasterDraftFromJson(Map<String, dynamic> json) =>
    _AiRasterDraft(
      rawWod: json['rawWod'] as String? ?? '',
      title: json['title'] as String? ?? '오늘의 수업',
      brief: json['brief'] as String? ?? '',
      bodyFontSize: (json['bodyFontSize'] as num?)?.toDouble() ?? 42,
      groups:
          (json['groups'] as List<dynamic>?)
              ?.map((e) => AiRasterGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$AiRasterDraftToJson(_AiRasterDraft instance) =>
    <String, dynamic>{
      'rawWod': instance.rawWod,
      'title': instance.title,
      'brief': instance.brief,
      'bodyFontSize': instance.bodyFontSize,
      'groups': instance.groups.map((e) => e.toJson()).toList(),
    };

_AiRasterAsset _$AiRasterAssetFromJson(Map<String, dynamic> json) =>
    _AiRasterAsset(
      sha256: json['sha256'] as String,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      sourceRect:
          (json['sourceRect'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$AiRasterAssetToJson(_AiRasterAsset instance) =>
    <String, dynamic>{
      'sha256': instance.sha256,
      'width': instance.width,
      'height': instance.height,
      'sourceRect': instance.sourceRect,
    };

_AiRasterBrand _$AiRasterBrandFromJson(Map<String, dynamic> json) =>
    _AiRasterBrand(
      key: json['key'] as String,
      revision: (json['revision'] as num).toInt(),
      catalogRevision: (json['catalogRevision'] as num).toInt(),
      recipeRevision: (json['recipeRevision'] as num).toInt(),
      templateId: json['templateId'] as String,
      name: json['name'] as String,
      reference: AiRasterAsset.fromJson(
        json['reference'] as Map<String, dynamic>,
      ),
      logo: AiRasterAsset.fromJson(json['logo'] as Map<String, dynamic>),
      backgroundColor: json['backgroundColor'] as String,
      textColor: json['textColor'] as String,
      accentColor: json['accentColor'] as String,
    );

Map<String, dynamic> _$AiRasterBrandToJson(_AiRasterBrand instance) =>
    <String, dynamic>{
      'key': instance.key,
      'revision': instance.revision,
      'catalogRevision': instance.catalogRevision,
      'recipeRevision': instance.recipeRevision,
      'templateId': instance.templateId,
      'name': instance.name,
      'reference': instance.reference.toJson(),
      'logo': instance.logo.toJson(),
      'backgroundColor': instance.backgroundColor,
      'textColor': instance.textColor,
      'accentColor': instance.accentColor,
    };

_AiRasterJob _$AiRasterJobFromJson(Map<String, dynamic> json) => _AiRasterJob(
  requestId: json['requestId'] as String,
  status: json['status'] as String,
  brandKey: json['brandKey'] as String,
  draft: AiRasterDraft.fromJson(json['draft'] as Map<String, dynamic>),
  artifact: json['artifact'] == null
      ? null
      : AiRasterAsset.fromJson(json['artifact'] as Map<String, dynamic>),
  expiresAtMs: (json['expiresAtMs'] as num?)?.toInt(),
  message: json['message'] as String?,
);

Map<String, dynamic> _$AiRasterJobToJson(_AiRasterJob instance) =>
    <String, dynamic>{
      'requestId': instance.requestId,
      'status': instance.status,
      'brandKey': instance.brandKey,
      'draft': instance.draft.toJson(),
      'artifact': instance.artifact?.toJson(),
      'expiresAtMs': instance.expiresAtMs,
      'message': instance.message,
    };
