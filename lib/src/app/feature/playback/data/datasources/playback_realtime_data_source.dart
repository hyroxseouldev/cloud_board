import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/core/services/realtime_connection.dart';
import 'package:cloud_board/src/app/core/services/event_id.dart';
export 'package:cloud_board/src/app/core/services/realtime_connection.dart'
    show waitForPlaybackConnection;
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';

import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_command.dart';

import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
import 'package:collection/collection.dart';

import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';

class PlaybackRealtimeDataSource {
  PlaybackRealtimeDataSource(
    this._database,
    this._ownerId, {
    this.serverRead,
    this.onAncillaryFailure,
  });

  final Future<Object?> Function(String path)? serverRead;
  final void Function(Object error, StackTrace stack)? onAncillaryFailure;
  final _refreshes = StreamController<PlaybackSessionModel?>.broadcast();
  bool _recovering = false;
  int _generation = 0;
  PlaybackSessionModel? _verified;
  String? _removedSessionId;
  bool _disposed = false;

  Future<void> dispose() {
    _disposed = true;
    ++_generation;
    return _refreshes.close();
  }

  /// Explicit resume handshake. REST reads cannot silently fall back to SDK cache.
  Future<PlaybackSessionModel?> recover({
    required bool restartTransport,
  }) async {
    if (_disposed) throw StateError('계정 연결이 변경되었습니다.');
    final read = serverRead;
    if (read == null) throw StateError('서버 상태 확인을 사용할 수 없습니다.');
    final previousId = _lastWireState?['id'] as String?;
    _recovering = true;
    final generation = ++_generation;
    final elapsed = Stopwatch()..start();
    try {
      if (restartTransport) {
        try {
          await _database.goOffline();
        } finally {
          await _database.goOnline();
        }
      } else {
        await _database.goOnline();
      }
      await watchConnected()
          .firstWhere((value) => value)
          .timeout(const Duration(seconds: 6));
      debugPrint(
        'Playback recovery: transport connected in ${elapsed.elapsedMilliseconds}ms',
      );
      final value = await read('users/${_requireOwnerId()}/activeSession');
      if (value is Map &&
          value['schemaVersion'] == 2 &&
          !_snapshots.containsKey(value['snapshotId'])) {
        final id = value['id'];
        if (id is! String || value['snapshotId'] != id) {
          throw const FormatException('수업 자료 버전이 일치하지 않습니다.');
        }
        _rememberSnapshot(
          id,
          _stringMap(
            await read('users/${_requireOwnerId()}/playbackSnapshots/$id'),
          ),
        );
      }
      final model = value == null ? null : _decode(value);
      if (generation != _generation) throw StateError('수업 상태 확인이 취소되었습니다.');
      _verified = model;
      _removedSessionId = model == null ? previousId : null;
      _refreshes.add(model);
      return model;
    } finally {
      if (generation == _generation) _recovering = false;
    }
  }

  final FirebaseDatabase _database;
  final String? _ownerId;
  final _snapshots = <String, Map<String, dynamic>>{};
  final _snapshotLoads = <String, Future<void>>{};

  void _rememberSnapshot(String id, Map<String, dynamic> snapshot) {
    _snapshots[id] = snapshot;
    while (_snapshots.length > 3) {
      _snapshots.remove(_snapshots.keys.first);
    }
  }

  Future<void> _ensureSnapshot(Object? value) async {
    if (value is! Map || value['schemaVersion'] != 2) return;
    final id = value['id'];
    if (id is! String || value['snapshotId'] != id) {
      throw const FormatException('수업 자료 버전이 일치하지 않습니다.');
    }
    if (_snapshots.containsKey(id)) return;
    await (_snapshotLoads[id] ??= () async {
      try {
        final snapshot = await _user.child('playbackSnapshots/$id').get();
        _snapshots[id] = _stringMap(snapshot.value);
        // Keep only a small number of immutable snapshots across sessions.
        while (_snapshots.length > 3) {
          _snapshots.remove(_snapshots.keys.first);
        }
      } finally {
        _snapshotLoads.remove(id);
      }
    }());
  }

  Map? _lastWireState;
  Object? _rawWorkout;
  Map<String, dynamic>? _workout;

  PlaybackSessionModel _decode(Object? value) {
    if (value is! Map) throw const FormatException('재생 세션 형식이 올바르지 않습니다.');
    final rawWorkout = value['schemaVersion'] == 2
        ? _snapshots[value['snapshotId']]
        : value['workoutSnapshot'];
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
    final model = PlaybackSessionModel.fromJson(json);
    _lastWireState = value;
    return model;
  }

  DatabaseReference get _active =>
      _database.ref('users/${_requireOwnerId()}/activeSession');

  DatabaseReference get _user => _database.ref('users/${_requireOwnerId()}');

  Stream<PlaybackSessionModel?> watchActive() {
    if (_ownerId == null) return Stream.value(null);
    return Stream.multi((sink) {
      final remote = _active.onValue
          .asyncMap((event) async {
            final generation = _generation;
            final value = event.snapshot.value;
            if (_recovering) return (deliver: false, model: null);
            if (value != null) await _ensureSnapshot(value);
            final model = value == null ? null : _decode(value);
            final verified = _verified;
            final stale =
                model != null &&
                verified != null &&
                (model.id == verified.id
                    ? model.revision < verified.revision
                    : model.anchorServerMs < verified.anchorServerMs);
            return (
              deliver:
                  !_recovering &&
                  generation == _generation &&
                  !stale &&
                  (model == null || model.id != _removedSessionId),
              model: model,
            );
          })
          .listen(
            (event) {
              if (event.deliver) sink.add(event.model);
            },
            onError: sink.addError,
            onDone: sink.close,
          );
      final refreshed = _refreshes.stream.listen(
        sink.add,
        onError: sink.addError,
      );
      sink.onCancel = () async {
        await remote.cancel();
        await refreshed.cancel();
      };
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
    if (value is! Map || value['status'] == 'completed') return false;
    await _ensureSnapshot(value);
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
    await waitForPlaybackConnection(watchConnected());
    final devices = (await _user.child('devices').get()).value;
    for (final id in model.targetDeviceIds) {
      if (devices is! Map || !isRegisteredDisplay(devices[id])) {
        throw StateError('연결이 완료된 디스플레이만 재생할 수 있습니다.');
      }
    }
    final workout = model.toEntity().workout;
    for (final module in workout.modules) {
      final error = timingValidationError(module);
      if (error != null) throw PlaybackFailure('invalid_timing', error);
    }
    final requiredProtocol = requiredTimingProtocol(workout);
    if (requiredProtocol > 1 && devices is Map) {
      final targets = model.targetDeviceIds.isEmpty
          ? devices.keys
          : model.targetDeviceIds;
      for (final id in targets) {
        final device = devices[id];
        if (isRegisteredDisplay(device) &&
            device is Map &&
            (device['playbackProtocol'] as num? ?? 1) < requiredProtocol) {
          throw PlaybackFailure(
            'display_update_required',
            requiredProtocol >= 4
                ? '라운드 반복과 독립 휴식을 재생하려면 연결된 디스플레이 앱을 업데이트해 주세요.'
                : '마지막 세트의 휴식을 동일하게 재생하려면 연결된 디스플레이 앱을 업데이트해 주세요.',
          );
        }
      }
    }
    final json = model.toJson()..['anchorServerMs'] = ServerValue.timestamp;
    // Older installed TVs continue receiving v1 until every registered display
    // has advertised support for immutable snapshots. Existing sessions never
    // change format while running. No capability means v1, not an assumption.
    final split = supportsSplitPlayback(devices);
    if (split) {
      json.remove('workoutSnapshot');
      json.addAll({
        'schemaVersion': 2,
        'snapshotId': model.id,
        'workoutId': model.workoutSnapshot['id'],
        'workoutName': model.workoutSnapshot['name'],
      });
      _rememberSnapshot(model.id, model.workoutSnapshot);
    }
    final event = _user.child('operations/events').push();
    final updates = <String, Object?>{
      'activeSession': json,
      if (split)
        'playbackSnapshots/${model.id}': {
          ...model.workoutSnapshot,
          '_storedAtMs': ServerValue.timestamp,
        },
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
    // Snapshot creation is immutable. Acquire the active slot transactionally;
    // two controllers starting together must never silently replace each other.
    final offset = await _serverOffset();
    final previous = (await _active.get()).value;
    if (previous != null) await _ensureSnapshot(previous);
    if (split) {
      await _user
          .child('playbackSnapshots/${model.id}')
          .set(updates.remove('playbackSnapshots/${model.id}'));
    }
    updates.remove('activeSession');
    final startExpiresAt =
        DateTime.now().millisecondsSinceEpoch + offset + 6000;
    json['notificationCommand'] = {
      'id': model.id,
      'expiresAtMs': startExpiresAt,
    };
    Object? rejection;
    StackTrace? rejectionStack;
    final result = await _active
        .runTransaction((current) {
          rejection = null;
          rejectionStack = null;
          if (DateTime.now().millisecondsSinceEpoch + offset >=
              startExpiresAt) {
            rejection = const PlaybackFailure(
              'command_expired',
              '수업 시작 요청이 만료됐습니다. 최신 상태를 확인해 주세요.',
            );
            return Transaction.abort();
          }
          if (current is Map && current['status'] != 'completed') {
            try {
              final session = _decode(current).toEntity();
              // Use the server clock offset already observed by this connection.
              final running = playbackPosition(
                session,
                playbackDurations(session.workout),
                DateTime.now().millisecondsSinceEpoch + offset,
              );
              if (session.briefing ||
                  session.status == PlaybackStatus.paused ||
                  running.index < playbackDurations(session.workout).length) {
                rejection = const PlaybackFailure(
                  'session_changed',
                  '이미 진행 중인 수업이 있습니다. 현재 수업을 종료한 뒤 시작해 주세요.',
                );
                return Transaction.abort();
              }
            } catch (error, stack) {
              rejection = error;
              rejectionStack = stack;
              return Transaction.abort();
            }
          }
          return Transaction.success(json);
        }, applyLocally: false)
        .timeout(const Duration(seconds: 8));
    if (!result.committed || result.snapshot.value == null) {
      Error.throwWithStackTrace(
        rejection ??
            const PlaybackFailure(
              'session_changed',
              '수업 시작 상태가 변경되었습니다. 다시 확인해 주세요.',
            ),
        rejectionStack ?? StackTrace.current,
      );
    }
    // Ancillary display/event writes must not turn an acknowledged start into
    // an apparent failure (and provoke a duplicate start).
    unawaited(
      _user.update(updates).catchError((Object error, StackTrace stack) {
        onAncillaryFailure?.call(error, stack);
      }),
    );
    return _decode(result.snapshot.value);
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
    await waitForPlaybackConnection(watchConnected());
    // Fetch only the small state in v2; the immutable workout is loaded once.
    final cached = _lastWireState;
    final observed =
        cached != null &&
            cached['id'] == expectedSessionId &&
            cached['revision'] == expectedRevision
        ? cached
        : (await _active.get()).value;
    if (observed is! Map ||
        observed['id'] != expectedSessionId ||
        observed['revision'] != expectedRevision) {
      throw PlaybackFailure(
        'revision_conflict',
        '다른 컨트롤러의 조작이 먼저 반영되었습니다. 최신 상태를 확인해 주세요.',
        expectedRevision: expectedRevision,
        observedRevision: observed is Map
            ? (observed['revision'] as num?)?.toInt()
            : null,
      );
    }
    await _ensureSnapshot(observed);
    final offset = await _serverOffset();
    final expiresAt = DateTime.now().millisecondsSinceEpoch + offset + 6000;
    final commandId = createEventId();
    var workoutId = '';
    var workoutName = '';
    var shouldRecordCompletion = false;
    var shouldRecordStart = false;
    Object? rejection;
    StackTrace? rejectionStack;
    final result = await _active
        .runTransaction((current) {
          rejection = null;
          rejectionStack = null;
          shouldRecordStart = false;
          shouldRecordCompletion = false;
          if (current is! Map ||
              current['id'] != expectedSessionId ||
              current['revision'] != expectedRevision ||
              current['schemaVersion'] != observed['schemaVersion']) {
            rejection = PlaybackFailure(
              'revision_conflict',
              '다른 컨트롤러의 조작이 먼저 반영되었습니다. 최신 상태를 확인해 주세요.',
              expectedRevision: expectedRevision,
              observedRevision: current is Map
                  ? (current['revision'] as num?)?.toInt()
                  : null,
              commandId: commandId,
            );
            rejectionStack = StackTrace.current;
            return Transaction.abort();
          }
          final json = Map<String, dynamic>.from(current);
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
          } catch (error, stack) {
            rejection = error;
            rejectionStack = stack;
            return Transaction.abort();
          }
          shouldRecordStart = requireBriefing;
          shouldRecordCompletion =
              status == 'completed' &&
              json['status'] != 'completed' &&
              json['briefing'] != true;
          final workout = json['schemaVersion'] == 2
              ? _snapshots[json['snapshotId']]
              : json['workoutSnapshot'];
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
          final currentSession = _decode(current).toEntity();
          final position = playbackPosition(
            currentSession,
            playbackDurations(currentSession.workout),
            DateTime.now().millisecondsSinceEpoch + offset,
          );
          json['startDelayMs'] = requireBriefing
              ? startDelayMs
              : (status == 'paused' || status == 'playing')
              ? position.countdownMs
              : 0;
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
      Error.throwWithStackTrace(
        rejection ??
            const PlaybackFailure(
              'revision_conflict',
              '수업 상태가 변경되었습니다. 최신 상태를 확인해 주세요.',
            ),
        rejectionStack ?? StackTrace.current,
      );
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

/// Gate the new wire format on explicit device capability, including offline TVs.
bool supportsSplitPlayback(Object? devices) {
  if (devices == null) return true;
  if (devices is! Map) return false;
  return devices.values
      .where(isRegisteredDisplay)
      .every(
        (value) =>
            value is Map && (value['playbackProtocol'] as num? ?? 1) >= 2,
      );
}
