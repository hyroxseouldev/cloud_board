import 'package:firebase_database/firebase_database.dart';
import 'package:collection/collection.dart';

import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';

class PlaybackRealtimeDataSource {
  PlaybackRealtimeDataSource(this._database, this._ownerId);

  final FirebaseDatabase _database;
  final String? _ownerId;
  Object? _rawWorkout;
  Map<String, dynamic>? _workout;

  PlaybackSessionModel _decode(Object? value) {
    if (value is! Map) throw const FormatException('재생 세션 형식이 올바르지 않습니다.');
    final rawWorkout = value['workoutSnapshot'];
    if (_workout == null ||
        !const DeepCollectionEquality().equals(_rawWorkout, rawWorkout)) {
      _rawWorkout = rawWorkout;
      _workout = _stringMap(rawWorkout);
    }
    // Reuse the immutable workout across revisions; normalize only small state.
    final json = <String, dynamic>{
      for (final entry in value.entries)
        if (entry.key != 'workoutSnapshot')
          entry.key.toString(): _normalizeValue(entry.value),
      'workoutSnapshot': _workout,
    };
    return PlaybackSessionModel.fromJson(json);
  }

  DatabaseReference get _active =>
      _database.ref('users/${_requireOwnerId()}/activeSession');

  DatabaseReference get _user => _database.ref('users/${_requireOwnerId()}');

  Stream<PlaybackSessionModel?> watchActive() {
    if (_ownerId == null) return Stream.value(null);
    return _active.onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return null;
      return _decode(value);
    });
  }

  Stream<int> watchServerTimeOffset() => _database
      .ref('.info/serverTimeOffset')
      .onValue
      .map((event) => (event.snapshot.value as num?)?.round() ?? 0);

  Stream<bool> watchConnected() => _database
      .ref('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);

  Future<bool> hasRunningSession() async {
    final snapshot = await _active.get();
    final value = snapshot.value;
    if (value is! Map) return false;
    return value['status'] != 'completed';
  }

  Future<PlaybackSessionModel> start(
    PlaybackSessionModel model, {
    bool scheduled = false,
    int? scheduledAtMs,
  }) async {
    final json = model.toJson()..['anchorServerMs'] = ServerValue.timestamp;
    final event = _user.child('operations/events').push();
    final updates = <String, Object?>{
      'activeSession': json,
      'operations/events/${event.key}': {
        'id': event.key,
        'type': model.briefing ? 'briefing_opened' : 'playback_started',
        'occurredAtMs': ServerValue.timestamp,
        'deviceId': model.updatedByDeviceId,
        'workoutId': model.workoutSnapshot['id'],
        'workoutName': model.workoutSnapshot['name'],
        'scheduled': scheduled,
        'scheduledAtMs': scheduledAtMs,
      },
    };
    for (final deviceId in model.targetDeviceIds) {
      updates['devices/$deviceId/displayState'] = 'auto';
      updates['devices/$deviceId/lastCommandAtMs'] = ServerValue.timestamp;
    }
    await _user.update(updates);
    final snapshot = await _active.get();
    return _decode(snapshot.value);
  }

  Future<PlaybackSessionModel> update({
    required String status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
    bool requireBriefing = false,
    String? expectedSessionId,
  }) async {
    var workoutId = '';
    var workoutName = '';
    var shouldRecordCompletion = false;
    var shouldRecordStart = false;
    final result = await _active.runTransaction((current) {
      if (current == null) return Transaction.abort();
      final json = Map<String, dynamic>.from(current as Map);
      if (json['status'] == 'completed' ||
          (expectedSessionId != null && json['id'] != expectedSessionId)) {
        return Transaction.abort();
      }
      if (requireBriefing && json['briefing'] != true) {
        return Transaction.abort();
      }
      shouldRecordStart = requireBriefing;
      shouldRecordCompletion =
          status == 'completed' &&
          json['status'] != 'completed' &&
          json['briefing'] != true;
      final workout = json['workoutSnapshot'];
      if (workout is Map) {
        workoutId = workout['id']?.toString() ?? '';
        workoutName = workout['name']?.toString() ?? '';
      }
      json.putIfAbsent('zoneId', () => 'main');
      json['status'] = status;
      json['briefing'] = false;
      json['startDelayMs'] = startDelayMs;
      json['updatedByDeviceId'] = deviceId;
      json['revision'] = ((json['revision'] as num?)?.round() ?? 0) + 1;
      json['anchorServerMs'] = ServerValue.timestamp;
      if (stepIndex != null) json['stepIndex'] = stepIndex;
      if (remainingMs != null) json['remainingMs'] = remainingMs;
      return Transaction.success(json);
    });
    if (!result.committed || result.snapshot.value == null) {
      throw StateError('재생 세션을 업데이트하지 못했습니다.');
    }
    if (shouldRecordCompletion || shouldRecordStart) {
      final event = _user.child('operations/events').push();
      await event.set({
        'id': event.key,
        'type': shouldRecordStart ? 'playback_started' : 'playback_completed',
        'occurredAtMs': ServerValue.timestamp,
        'deviceId': deviceId,
        'workoutId': workoutId,
        'workoutName': workoutName,
        'scheduled': false,
      });
    }
    return _decode(result.snapshot.value);
  }

  String _requireOwnerId() {
    final ownerId = _ownerId;
    if (ownerId == null) throw StateError('연결된 매장을 찾을 수 없습니다.');
    return ownerId;
  }
}

Map<String, dynamic> _stringMap(Object? value) {
  if (value is! Map) throw const FormatException('재생 세션 형식이 올바르지 않습니다.');
  return value.map(
    (key, item) => MapEntry(key.toString(), _normalizeValue(item)),
  );
}

Object? _normalizeValue(Object? value) {
  if (value is Map) return _stringMap(value);
  if (value is List) return value.map(_normalizeValue).toList();
  return value;
}
