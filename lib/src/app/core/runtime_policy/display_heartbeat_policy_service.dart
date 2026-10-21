import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/core/runtime_policy/remote_feature_rollout.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_heartbeat_policy.dart';

part 'display_heartbeat_policy_service.g.dart';

const displayHeartbeatParameter = 'cloudboard_display_heartbeat_v1';

class DisplayHeartbeatPolicyService {
  DisplayHeartbeatPolicyService({
    required this.fetch,
    required this.readCache,
    required this.writeCache,
  });
  final Future<Map<String, dynamic>?> Function() fetch;
  final Future<String?> Function() readCache;
  final Future<void> Function(String) writeCache;
  DisplayHeartbeatPolicy _lastGood = DisplayHeartbeatPolicy.target;
  Future<void>? _restoring;
  Future<DisplayHeartbeatPolicy>? _loading;

  Future<void> _restore() async {
    try {
      final raw = await readCache();
      if (raw != null) {
        _lastGood = DisplayHeartbeatPolicy.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
  }

  Future<DisplayHeartbeatPolicy> load() =>
      _loading ??= _load().whenComplete(() => _loading = null);

  Future<DisplayHeartbeatPolicy> _load() async {
    await (_restoring ??= _restore());
    try {
      final raw = await fetch().timeout(const Duration(seconds: 4));
      if (raw != null) {
        final next = DisplayHeartbeatPolicy.fromJson(raw);
        if (next.revision > _lastGood.revision) {
          _lastGood = next;
          try {
            await writeCache(jsonEncode(next.toJson()));
          } catch (_) {}
        }
      }
    } catch (_) {}
    return _lastGood;
  }
}

@Riverpod(keepAlive: true)
DisplayHeartbeatPolicyService displayHeartbeatPolicyService(Ref ref) {
  String cacheKey() =>
      'cloudboard.heartbeat.v1.${Firebase.app().options.projectId}';
  return DisplayHeartbeatPolicyService(
    fetch: () => fetchRemotePolicyParameter(displayHeartbeatParameter),
    readCache: () => SharedPreferencesAsync().getString(cacheKey()),
    writeCache: (value) =>
        SharedPreferencesAsync().setString(cacheKey(), value),
  );
}
