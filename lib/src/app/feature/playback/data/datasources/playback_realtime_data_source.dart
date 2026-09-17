import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_command.dart';

import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
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
    final session = _decode(value).toEntity();
    final offset = await _serverOffset();
    return playbackPosition(
          session,
          playbackDurations(session.workout),
          DateTime.now().millisecondsSinceEpoch + offset,
        ).index <
        playbackDurations(session.workout).length;
  }

  Future<PlaybackSessionModel> start(
    PlaybackSessionModel model, {
    bool scheduled = false,
    int? scheduledAtMs,
  }) async {
    if (!await watchConnected().first.timeout(const Duration(seconds: 3))) {
      throw StateError('컨트롤러의 서버 연결을 확인해 주세요.');
    }
    final devices = (await _user.child('devices').get()).value;
    for (final id in model.targetDeviceIds) {
      if (devices is! Map || !isRegisteredDisplay(devices[id])) {
        throw StateError('연결이 완료된 디스플레이만 재생할 수 있습니다.');
      }
    }
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
    required String? status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
    bool requireBriefing = false,
    required String expectedSessionId,
    required int expectedRevision,
  }) async {
    if (!await watchConnected().first.timeout(const Duration(seconds: 3))) {
      throw StateError('컨트롤러의 서버 연결을 확인해 주세요.');
    }
    final offset = await _serverOffset();
    final expiresAt = DateTime.now().millisecondsSinceEpoch + offset + 6000;
    final commandId =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    var workoutId = '';
    var workoutName = '';
    var shouldRecordCompletion = false;
    var shouldRecordStart = false;
    final result = await _active
        .runTransaction((current) {
          if (current == null) return Transaction.abort();
          final json = Map<String, dynamic>.from(current as Map);
          late final ({String status, int stepIndex, int remainingMs}) command;
          try {
            command = resolvePlaybackCommand(
              session: _decode(current).toEntity(),
              expectedSessionId: expectedSessionId,
              expectedRevision: expectedRevision,
              serverNowMs: DateTime.now().millisecondsSinceEpoch + offset,
              expiresAtMs: expiresAt,
              status: status,
              stepIndex: stepIndex,
              remainingMs: remainingMs,
              requireBriefing: requireBriefing,
            );
          } on StateError {
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
          json['status'] = command.status;
          json['stepIndex'] = command.stepIndex;
          json['remainingMs'] = command.remainingMs;
          // Reuse the already deployed deadline rule used by native notifications.
          json['notificationCommand'] = {
            'id': commandId,
            'expiresAtMs': expiresAt,
          };
          json['briefing'] = false;
          json['startDelayMs'] = startDelayMs;
          json['updatedByDeviceId'] = deviceId;
          json['revision'] = ((json['revision'] as num?)?.round() ?? 0) + 1;
          json['anchorServerMs'] = ServerValue.timestamp;
          return Transaction.success(json);
        }, applyLocally: false)
        .timeout(
          const Duration(seconds: 6),
          onTimeout: () {
            // A queued SDK transaction cannot commit after the server deadline.
            throw TimeoutException('명령 결과를 확인하지 못했습니다. 연결 후 수업 상태를 확인해 주세요.');
          },
        );
    if (!result.committed || result.snapshot.value == null) {
      throw StateError('수업 상태가 변경되었거나 명령이 만료됐습니다. 현재 상태를 확인하고 다시 시도해 주세요.');
    }
    if (shouldRecordCompletion || shouldRecordStart) {
      final event = _user.child('operations/events').push();
      unawaited(
        event
            .set({
              'id': event.key,
              'type': shouldRecordStart
                  ? 'playback_started'
                  : 'playback_completed',
              'occurredAtMs': ServerValue.timestamp,
              'deviceId': deviceId,
              'workoutId': workoutId,
              'workoutName': workoutName,
              'scheduled': false,
            })
            .catchError((Object _) {}),
      );
    }
    return _decode(result.snapshot.value);
  }

  // .info is SDK-local metadata. get() makes a server read on Apple platforms
  // and can fail with permission-denied even when the client is connected.
  Future<int> _serverOffset() =>
      watchServerTimeOffset().first.timeout(const Duration(seconds: 3));

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
