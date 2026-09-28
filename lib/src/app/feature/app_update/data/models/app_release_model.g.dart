// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_release_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppReleaseModel _$AppReleaseModelFromJson(Map<String, dynamic> json) =>
    AppReleaseModel(
      latestBuild: (json['latestBuild'] as num).toInt(),
      minimumBuild: (json['minimumBuild'] as num).toInt(),
      publishedBuild: (json['publishedBuild'] as num).toInt(),
      version: json['version'] as String,
      storeUrl: json['storeUrl'] as String,
      message:
          json['message'] as String? ?? '더 편리하고 안정적인 수업을 위해 최신 버전으로 업데이트해 주세요.',
      enabled: json['enabled'] as bool? ?? false,
      published: json['published'] as bool? ?? false,
    );
