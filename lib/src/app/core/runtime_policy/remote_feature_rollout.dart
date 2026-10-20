import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Remote Config controls optional feature rollout only. Version requirements
/// remain in appReleases. Call only before a new operation, never from an active
/// session listener: the selected playback protocol stays in that session.
const remoteFeatureParameter = 'cloudboard_optional_features_v1';

Future<Map<String, dynamic>?> fetchRemoteFeatureRollout() =>
    fetchRemotePolicyParameter(remoteFeatureParameter);

Future<Map<String, dynamic>?> fetchRemotePolicyParameter(
  String parameter,
) async {
  if (Firebase.app().options.projectId.startsWith('demo-')) return null;
  final config = FirebaseRemoteConfig.instance;
  await config.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 3),
      minimumFetchInterval: const Duration(minutes: 15),
    ),
  );
  await config.setDefaults({parameter: ''});
  try {
    // Activation happens at this new-operation boundary. There is deliberately
    // no onConfigUpdated listener that could change an ongoing lesson.
    await config.fetch();
    await config.activate();
  } catch (_) {
    // The SDK's activated value can still be used after a network failure. The
    // service additionally keeps its last validated application cache.
  }
  final value = config.getString(parameter);
  if (value.isEmpty) return null;
  return jsonDecode(value) as Map<String, dynamic>;
}
