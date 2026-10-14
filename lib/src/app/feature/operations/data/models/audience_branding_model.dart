import 'package:json_annotation/json_annotation.dart';

import 'package:cloud_board/src/app/feature/operations/domain/entities/audience_branding.dart';

part 'audience_branding_model.g.dart';

/// Only read from the server-owned operations/brandProjection node. Editable
/// brand labels, brandConfig and legacy brand caches cannot create this model.
@JsonSerializable()
class AudienceBrandingModel {
  const AudienceBrandingModel({
    required this.ownerId,
    required this.policyVersion,
    required this.audienceLogoVersion,
    required this.audienceLogoScope,
    required this.showCloudBoardLogo,
    required this.revision,
    required this.projectionRevision,
    required this.appliedAtMs,
    required this.validUntilMs,
  });

  final String ownerId;
  final String policyVersion;
  final String audienceLogoVersion;
  final String audienceLogoScope;
  final bool showCloudBoardLogo;
  final int revision;
  final int projectionRevision;
  final int appliedAtMs;
  final int validUntilMs;

  factory AudienceBrandingModel.fromJson(Map<String, dynamic> json) =>
      _$AudienceBrandingModelFromJson(json);
  Map<String, dynamic> toJson() => _$AudienceBrandingModelToJson(this);

  static AudienceBrandingModel? parse(Object? value, String ownerId) {
    if (value is! Map || value.keys.any((key) => key is! String)) return null;
    final json = Map<String, dynamic>.from(value);
    if (json['ownerId'] != ownerId ||
        json['policyVersion'] != 'plan-entitlements-v2' ||
        json['audienceLogoVersion'] != 'audience-logo-v1' ||
        !const [
          'standby',
          'all-audience',
        ].contains(json['audienceLogoScope']) ||
        json['showCloudBoardLogo'] is! bool) {
      return null;
    }
    // Do not truncate malformed fractional timestamps/revisions into a valid
    // policy. Web JSON numbers may still arrive as integral doubles.
    for (final key in [
      'revision',
      'projectionRevision',
      'appliedAtMs',
      'validUntilMs',
    ]) {
      final number = json[key];
      if (number is! num ||
          !number.isFinite ||
          number < 0 ||
          number > 9007199254740991 ||
          number != number.truncateToDouble()) {
        return null;
      }
    }
    if ((json['validUntilMs'] as num) <= (json['appliedAtMs'] as num)) {
      return null;
    }
    return AudienceBrandingModel.fromJson(json);
  }

  bool supersedes(AudienceBrandingModel? previous) =>
      previous == null ||
      (ownerId == previous.ownerId &&
          revision >= previous.revision &&
          (projectionRevision > previous.projectionRevision ||
              (projectionRevision == previous.projectionRevision &&
                  toEntity() == previous.toEntity())));

  AudienceBranding toEntity() => AudienceBranding(
    ownerId: ownerId,
    revision: revision,
    projectionRevision: projectionRevision,
    appliedAtMs: appliedAtMs,
    validUntilMs: validUntilMs,
    scope: audienceLogoScope == 'all-audience'
        ? AudienceLogoScope.allAudience
        : AudienceLogoScope.standby,
    showCloudBoardLogo: showCloudBoardLogo,
  );
}
