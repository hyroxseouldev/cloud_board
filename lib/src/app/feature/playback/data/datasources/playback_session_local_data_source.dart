import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';

part 'playback_session_local_data_source.g.dart';

/// The workout is written once; frequent checkpoints contain only playback state.
/// Snapshot-before-pointer writes and a single queue preserve crash recovery and
/// ordering, including when account-dependent repositories are replaced.
class PlaybackSessionLocalDataSource {
  PlaybackSessionLocalDataSource(this._preferences);

  static const _legacyKey = 'xonboard.active-playback.v1';
  static const _stateKey = 'xonboard.active-playback.v2';
  final SharedPreferencesAsync _preferences;
  Future<void> _pending = Future.value();
  PlaybackSessionModel? _cached;
  bool _loaded = false;
  String? _snapshotKey;
  String? _checkpoint;
  int _snapshotVersion = 0;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<PlaybackSessionModel?> load() => _enqueue(_load);

  Future<PlaybackSessionModel?> _load() async {
    if (_loaded) return _cached;
    final raw = await _preferences.getString(_stateKey);
    if (raw != null) {
      try {
        final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final key = json.remove('snapshotKey') as String;
        final snapshot = await _preferences.getString(key);
        if (snapshot == null) throw const FormatException('Missing workout');
        json['workoutSnapshot'] = jsonDecode(snapshot);
        _cached = PlaybackSessionModel.fromJson(json);
        _snapshotKey = key;
        _checkpoint = raw;
        _loaded = true;
        return _cached;
      } on FormatException {
        await _preferences.remove(_stateKey);
      } on TypeError {
        await _preferences.remove(_stateKey);
      }
    }
    final legacy = await _preferences.getString(_legacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        final model = PlaybackSessionModel.fromJson(
          Map<String, dynamic>.from(jsonDecode(legacy) as Map),
        );
        await _save(model);
        await _preferences.remove(_legacyKey);
        return model;
      } on FormatException {
        await _preferences.remove(_legacyKey);
      } on TypeError {
        await _preferences.remove(_legacyKey);
      }
    }
    _loaded = true;
    return null;
  }

  Future<void> save(PlaybackSessionModel session) => _enqueue(() async {
    await _load();
    await _save(session);
  });

  Future<void> _save(PlaybackSessionModel session) async {
    final sameSnapshot =
        _snapshotKey != null &&
        _cached?.ownerId == session.ownerId &&
        _cached?.id == session.id &&
        const DeepCollectionEquality().equals(
          _cached?.workoutSnapshot,
          session.workoutSnapshot,
        );
    final previousKey = _snapshotKey;
    final key = sameSnapshot
        ? previousKey!
        : 'xonboard.playback-workout.v2.${DateTime.now().microsecondsSinceEpoch}.${_snapshotVersion++}';
    if (!sameSnapshot) {
      await _preferences.setString(key, jsonEncode(session.workoutSnapshot));
    }
    final state = session.toJson()..remove('workoutSnapshot');
    state['snapshotKey'] = key;
    final checkpoint = jsonEncode(state);
    if (checkpoint != _checkpoint) {
      await _preferences.setString(_stateKey, checkpoint);
    }
    _cached = session;
    _snapshotKey = key;
    _checkpoint = checkpoint;
    _loaded = true;
    // Only remove the old snapshot after the checkpoint write succeeds.
    if (previousKey != null && previousKey != key) {
      await _preferences.remove(previousKey);
    }
  }

  Future<PlaybackSessionModel?> update({
    required String status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
  }) => _enqueue(() async {
    final current = await _load();
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
    await _save(updated);
    return updated;
  });

  Future<void> clear() => _enqueue(() async {
    await _load();
    await _preferences.remove(_stateKey);
    await _preferences.remove(_legacyKey);
    final key = _snapshotKey;
    _cached = null;
    _snapshotKey = null;
    _checkpoint = null;
    _loaded = true;
    if (key != null) await _preferences.remove(key);
  });
}

@Riverpod(keepAlive: true)
PlaybackSessionLocalDataSource playbackSessionLocalDataSource(Ref ref) =>
    PlaybackSessionLocalDataSource(SharedPreferencesAsync());
