import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/core/runtime_policy/runtime_feature_policy.dart';
import 'package:cloud_board/src/app/core/runtime_policy/remote_feature_rollout.dart';

part 'runtime_feature_policy_service.g.dart';

/// Fetch on each new optional operation; outages retain the last validated
/// policy. Cache is scoped to Firebase project and contains no account data.
class RuntimeFeaturePolicyService {
  RuntimeFeaturePolicyService({
    required this.fetch,
    required this.readCache,
    required this.writeCache,
    this.additionalAllows,
  });
  final Future<Map<String, dynamic>?> Function() fetch;
  final Future<String?> Function() readCache;
  final Future<void> Function(String) writeCache;
  final Future<bool> Function(RuntimeFeature feature, String ownerId)?
  additionalAllows;
  RuntimeFeaturePolicy _lastGood = RuntimeFeaturePolicy.defaults;
  Future<void>? _restoring;

  Future<void> _restore() async {
    try {
      final raw = await readCache();
      if (raw != null) {
        _lastGood = RuntimeFeaturePolicy.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // A corrupt or unavailable local cache must not block ordinary use.
    }
  }

  Future<RuntimeFeaturePolicy> load() async {
    await (_restoring ??= _restore());
    try {
      final data = await fetch().timeout(const Duration(seconds: 4));
      // No document on a fresh installation preserves current functionality.
      // Deleting a policy is not an emergency reset: retain a known good policy.
      if (data != null) {
        final next = RuntimeFeaturePolicy.fromJson(data);
        if (next.revision >= _lastGood.revision) {
          _lastGood = next;
          try {
            await writeCache(jsonEncode(next.toJson()));
          } catch (_) {
            // The valid in-memory policy still applies if disk is full.
          }
        }
      }
    } catch (_) {
      // Policy rollout must not turn a Firebase/network outage into a lockout.
    }
    return _lastGood;
  }

  Future<bool> allows(RuntimeFeature feature, {required String ownerId}) async {
    final results = await Future.wait([
      load().then((policy) => policy.allows(feature, ownerId: ownerId)),
      if (additionalAllows != null) additionalAllows!(feature, ownerId),
    ]);
    // A new rollout must never override an existing compatibility kill switch.
    return results.every((allowed) => allowed);
  }
}

@Riverpod(keepAlive: true)
RuntimeFeaturePolicyService runtimeFeaturePolicyService(Ref ref) {
  String cacheKey() =>
      'cloudboard.runtime-policy.v1.${FirebaseFirestore.instance.app.options.projectId}';
  final rollout = RuntimeFeaturePolicyService(
    fetch: fetchRemoteFeatureRollout,
    readCache: () => SharedPreferencesAsync().getString('${cacheKey()}.remote'),
    writeCache: (value) =>
        SharedPreferencesAsync().setString('${cacheKey()}.remote', value),
  );
  return RuntimeFeaturePolicyService(
    additionalAllows: (feature, ownerId) =>
        rollout.allows(feature, ownerId: ownerId),
    fetch: () async =>
        (await FirebaseFirestore.instance
                .doc('runtimePolicy/current')
                .get(const GetOptions(source: Source.server)))
            .data(),
    readCache: () => SharedPreferencesAsync().getString(cacheKey()),
    writeCache: (value) =>
        SharedPreferencesAsync().setString(cacheKey(), value),
  );
}
