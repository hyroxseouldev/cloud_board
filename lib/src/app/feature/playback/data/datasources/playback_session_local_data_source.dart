import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';

class PlaybackSessionLocalDataSource {
  const PlaybackSessionLocalDataSource(this._preferences);

  static const _storageKey = 'xonboard.active-playback.v1';
  final SharedPreferencesAsync _preferences;

  Future<PlaybackSessionModel?> load() async {
    final raw = await _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PlaybackSessionModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> save(PlaybackSessionModel session) =>
      _preferences.setString(_storageKey, jsonEncode(session.toJson()));

  Future<PlaybackSessionModel?> update({
    required String status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
  }) async {
    final current = await load();
    if (current == null) return null;
    final json = current.toJson()
      ..['status'] = status
      ..['briefing'] = false
      ..['startDelayMs'] = startDelayMs
      ..['updatedByDeviceId'] = deviceId
      ..['revision'] = current.revision + 1
      ..['anchorServerMs'] = DateTime.now().millisecondsSinceEpoch;
    if (stepIndex != null) json['stepIndex'] = stepIndex;
    if (remainingMs != null) json['remainingMs'] = remainingMs;
    final updated = PlaybackSessionModel.fromJson(json);
    await save(updated);
    return updated;
  }

  Future<void> clear() => _preferences.remove(_storageKey);
}
