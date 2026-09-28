import 'package:freezed_annotation/freezed_annotation.dart';
part 'app_release.freezed.dart';

enum UpdateKind { none, optional, required }

@freezed
abstract class AppRelease with _$AppRelease {
  const AppRelease._();
  const factory AppRelease({
    required int latestBuild,
    required int minimumBuild,
    required int publishedBuild,
    required String version,
    required String storeUrl,
    @Default('더 편리하고 안정적인 수업을 위해 최신 버전으로 업데이트해 주세요.') String message,
    @Default(false) bool enabled,
    @Default(false) bool published,
  }) = _AppRelease;

  bool validFor(String platform) {
    final uri = Uri.tryParse(storeUrl);
    final safe =
        uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        uri.fragment.isEmpty &&
        (platform == 'ios'
            ? uri.host == 'apps.apple.com' &&
                  RegExp(r'^/(?:[a-z]{2}/)?app/(?:[^/]+/)?id6809105126$')
                      .hasMatch(uri.path) &&
                  !uri.hasQuery
            : platform == 'android' &&
                  uri.host == 'play.google.com' &&
                  uri.path == '/store/apps/details' &&
                  uri.queryParameters.length == 1 &&
                  uri.queryParametersAll['id']?.length == 1 &&
                  uri.queryParameters['id'] == 'com.sunmkim.cloudboard');
    return enabled &&
        published &&
        safe &&
        version.trim().isNotEmpty &&
        version.length <= 32 &&
        minimumBuild > 0 &&
        latestBuild >= minimumBuild &&
        publishedBuild >= latestBuild &&
        latestBuild < 2147483647 &&
        message.length <= 500;
  }

  UpdateKind evaluate({required String platform, required int installedBuild}) {
    if (!validFor(platform) ||
        installedBuild <= 0 ||
        installedBuild >= latestBuild) {
      return UpdateKind.none;
    }
    return installedBuild < minimumBuild
        ? UpdateKind.required
        : UpdateKind.optional;
  }
}
