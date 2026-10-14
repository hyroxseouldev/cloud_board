import 'package:freezed_annotation/freezed_annotation.dart';

part 'audience_branding.freezed.dart';

enum AudienceLogoScope { standby, allAudience }

/// A server-confirmed rendering preference, never permission to start a class.
/// Keep the last confirmed appearance during offline playback, even if its
/// grant expires. Only a newer server projection changes the appearance.
@freezed
abstract class AudienceBranding with _$AudienceBranding {
  const AudienceBranding._();

  const factory AudienceBranding({
    required String ownerId,
    required int revision,
    required int projectionRevision,
    required int appliedAtMs,
    required int validUntilMs,
    required AudienceLogoScope scope,
    required bool showCloudBoardLogo,
  }) = _AudienceBranding;

  bool get includesClassScreens => scope == AudienceLogoScope.allAudience;

  /// Product copy only promises the expanded scope while the confirmed grant
  /// is current. Expiry does not alter an already running audience renderer.
  bool classScreensAvailableAt(int nowMs) =>
      includesClassScreens && validUntilMs > nowMs;
}
