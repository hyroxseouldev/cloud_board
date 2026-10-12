/// These switches only affect optional new operations. They are not access
/// control and never disable save, ordinary playback, or an active session.
enum RuntimeFeature { splitPlayback, aiSlideGeneration }

class RuntimeFeaturePolicy {
  const RuntimeFeaturePolicy({this.revision = 0, this.features = const {}});
  final int revision;
  final Map<RuntimeFeature, ({bool enabled, int rolloutPercent})> features;

  static const defaults = RuntimeFeaturePolicy();

  factory RuntimeFeaturePolicy.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['revision'] is! int ||
        (json['revision'] as int) < 0 ||
        json['features'] is! Map) {
      throw const FormatException('Unsupported runtime policy');
    }
    final features = <RuntimeFeature, ({bool enabled, int rolloutPercent})>{};
    final raw = json['features'] as Map;
    for (final feature in RuntimeFeature.values) {
      final value = raw[feature.name];
      if (value == null) continue; // Older policies keep current app defaults.
      if (value is! Map ||
          value['enabled'] is! bool ||
          value['rolloutPercent'] is! int ||
          (value['rolloutPercent'] as int) < 0 ||
          (value['rolloutPercent'] as int) > 100) {
        throw const FormatException('Invalid runtime feature rule');
      }
      features[feature] = (
        enabled: value['enabled'] as bool,
        rolloutPercent: value['rolloutPercent'] as int,
      );
    }
    return RuntimeFeaturePolicy(
      revision: json['revision'] as int,
      features: Map.unmodifiable(features),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'revision': revision,
    'features': {
      for (final entry in features.entries)
        entry.key.name: {
          'enabled': entry.value.enabled,
          'rolloutPercent': entry.value.rolloutPercent,
        },
    },
  };

  bool allows(RuntimeFeature feature, {required String ownerId}) {
    final rule = features[feature];
    if (rule == null) return true;
    if (!rule.enabled || rule.rolloutPercent == 0) return false;
    if (rule.rolloutPercent == 100) return true;
    // Stable across mobile/web process restarts; never use Dart's hashCode.
    var hash = 0;
    for (final unit in '${feature.name}:$ownerId'.codeUnits) {
      hash = (hash * 31 + unit) % 10000;
    }
    return hash % 100 < rule.rolloutPercent;
  }
}
