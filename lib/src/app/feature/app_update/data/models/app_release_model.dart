import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/entities/app_release.dart';
part 'app_release_model.g.dart';

@JsonSerializable(createToJson: false)
class AppReleaseModel {
  const AppReleaseModel({
    required this.latestBuild,
    required this.minimumBuild,
    required this.publishedBuild,
    required this.version,
    required this.storeUrl,
    this.message = '더 편리하고 안정적인 수업을 위해 최신 버전으로 업데이트해 주세요.',
    this.enabled = false,
    this.published = false,
  });
  final int latestBuild, minimumBuild, publishedBuild;
  final String version, storeUrl, message;
  final bool enabled, published;
  factory AppReleaseModel.fromJson(Map<String, dynamic> json) {
    for (final key in ['latestBuild', 'minimumBuild', 'publishedBuild']) {
      if (json[key] is! int) {
        throw const FormatException('Build must be an integer');
      }
    }
    return _$AppReleaseModelFromJson(json);
  }
  AppRelease toEntity() => AppRelease(
    latestBuild: latestBuild,
    minimumBuild: minimumBuild,
    publishedBuild: publishedBuild,
    version: version,
    storeUrl: storeUrl,
    message: message,
    enabled: enabled,
    published: published,
  );
}
