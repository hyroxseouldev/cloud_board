import 'package:cloud_board/src/app/feature/operations/data/operation_event_writer.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';
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
import 'package:cloud_board/src/app/feature/playback/data/models/playback_start_documents.dart';

class PlaybackRealtimeDataSource {
  PlaybackRealtimeDataSource(
    this._database,
    this._ownerId, {
    this.serverRead,
    this.onAncillaryFailure,
    this.allowSplitPlayback,
    this.appVersion,
    this.isCurrentAccount,
  });

  final String? appVersion;
  final Future<Object?> Function(String path)? serverRead;
  final Future<bool> Function()? allowSplitPlayback;
  final bool Function()? isCurrentAccount;
  final void Function(Object error, StackTrace stack)? onAncillaryFailure;
  final _refreshes = StreamController<PlaybackSessionModel?>.broadcast();
  late final _eventWriter = OperationEventWriter(
    (event) => _user
        .child('operations/events/${event.eventId ?? event.id}')
        .set(OperationEventModel.fromEntity(event).toJson()),
  );

  void _recordOperation(Map<String, dynamic> payload) {
    unawaited(
      _eventWriter.record(OperationEventModel.fromJson(payload).toEntity()),
    );
  }

  bool _recovering = false;
  int _generation = 0;
  // A verified null is a server-confirmed deletion, not an unknown value.
  bool _hasVerified = false;
  PlaybackSessionModel? _verified;
  PlaybackSessionModel? _accepted;
  int _acceptedVersion = 0;
  String? _removedSessionId;
  bool _disposed = false;

  Future<void> dispose() {
    _disposed = true;
    _eventWriter.dispose();
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
      final model = await _readServerSession(read);
      if (generation != _generation) throw StateError('수업 상태 확인이 취소되었습니다.');
      _hasVerified = true;
      _acceptActive(model);
      _refreshes.add(model);
      return model;
    } finally {
      if (generation == _generation) _recovering = false;
    }
  }

  Future<PlaybackSessionModel?> _readServerSession(
    Future<Object?> Function(String path) read,
  ) async {
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
    return value == null ? null : _decode(value);
  }

  void _acceptActive(PlaybackSessionModel? model) {
    // Repeated SDK receipts of the same revision are not a newer state. In
    // particular they must not supersede an in-flight deletion confirmation.
    if ((_accepted?.id, _accepted?.revision, _accepted?.anchorServerMs) !=
        (model?.id, model?.revision, model?.anchorServerMs)) {
      ++_acceptedVersion;
    }
    _removedSessionId = model == null
        ? _accepted?.id ?? _removedSessionId
        : null;
    _accepted = model;
    if (_hasVerified) _verified = model;
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
      if (_disposed) {
        sink.close();
        return;
      }
      // Recovery invalidates the Riverpod subscription. Broadcast refreshes do
      // not replay, and repository cache is deliberately suppressed after a
      // remote receipt. Seed verified state from the first SDK event, after any
      // null/non-null contradiction is confirmed, so recovery cannot report
      // success before a failed confirmation has reached the controller.
      var first = true;
      final remote = _active.onValue
          .asyncMap((event) async {
            final initial = first;
            first = false;
            final generation = _generation;
            final acceptedVersion = _acceptedVersion;
            final value = event.snapshot.value;
            if (_recovering || _disposed) return (deliver: false, model: null);
            if (value != null) await _ensureSnapshot(value);
            var model = value == null ? null : _decode(value);
            // The first SDK event may be cached. A null/non-null contradiction
            // cannot distinguish a real deletion/new class from an old cache.
            // Confirm only that ambiguous case, without restarting transport or
            // sending a control. Known removed IDs are already safe to ignore.
            if (initial &&
                _hasVerified &&
                (model == null) != (_verified == null) &&
                (model == null || model.id != _removedSessionId)) {
              try {
                model = await _readServerSession(serverRead!);
              } catch (_) {
                if (_disposed || generation != _generation || _recovering) {
                  return (deliver: false, model: null);
                }
                if (acceptedVersion == _acceptedVersion) rethrow;
              }
              // Another subscription may have accepted a newer SDK state while
              // this confirmation was pending. Deliver that state to this sink
              // too; never replace it with a delayed read or error.
              if (acceptedVersion != _acceptedVersion) model = _verified;
            }
            final verified = _verified;
            final stale =
                model != null &&
                verified != null &&
                (model.id == verified.id
                    ? model.revision < verified.revision
                    : model.anchorServerMs < verified.anchorServerMs);
            final rejected =
                stale || (model != null && model.id == _removedSessionId);
            return (
              deliver:
                  !_disposed &&
                  !_recovering &&
                  generation == _generation &&
                  (!rejected || (initial && _hasVerified)),
              model: rejected ? _verified : model,
            );
          })
          .listen(
            (event) {
              if (event.deliver) {
                _acceptActive(event.model);
                sink.add(event.model);
              }
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
    void Function()? ensureCurrent,
  }) async {
    void ensureStartCurrent() {
      _ensureStartAccount();
      ensureCurrent?.call();
    }

    ensureStartCurrent();
    await waitForPlaybackConnection(watchConnected());
    ensureStartCurrent();
    final devices = (await _user.child('devices').get()).value;
    ensureStartCurrent();
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
            requiredProtocol >= 5
                ? '새 타이머 방식을 재생하려면 연결된 디스플레이 앱을 업데이트해 주세요.'
                : requiredProtocol >= 4
                ? '라운드 반복과 독립 휴식을 재생하려면 연결된 디스플레이 앱을 업데이트해 주세요.'
                : '마지막 세트의 휴식을 동일하게 재생하려면 연결된 디스플레이 앱을 업데이트해 주세요.',
          );
        }
      }
    }
    // Older installed TVs continue receiving v1 until every registered display
    // has advertised support for immutable snapshots. Existing sessions never
    // change format while running. No capability means v1, not an assumption.
    final split =
        supportsSplitPlayback(devices) &&
        (await allowSplitPlayback?.call() ?? true);
    ensureStartCurrent();
    final documents = PlaybackStartDocuments(model, split: split);
    final json = documents.state;
    if (split) {
      _rememberSnapshot(model.id, model.workoutSnapshot);
    }
    final updates = <String, Object?>{
      'activeSession': json,
      if (split) 'playbackSnapshots/${model.id}': documents.snapshot,
    };
    for (final deviceId in model.targetDeviceIds) {
      updates['devices/$deviceId/displayState'] = 'auto';
      updates['devices/$deviceId/lastCommandAtMs'] = ServerValue.timestamp;
    }
    // Snapshot creation is immutable. Acquire the active slot transactionally;
    // two controllers starting together must never silently replace each other.
    final offset = await _serverOffset();
    ensureStartCurrent();
    final previous = (await _active.get()).value;
    ensureStartCurrent();
    if (previous != null) await _ensureSnapshot(previous);
    ensureStartCurrent();
    if (split) {
      await _user
          .child('playbackSnapshots/${model.id}')
          .set(updates.remove('playbackSnapshots/${model.id}'));
    }
    ensureStartCurrent();
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
          try {
            ensureStartCurrent();
          } catch (error, stack) {
            rejection = error;
            rejectionStack = stack;
            return Transaction.abort();
          }
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
    final started = _decode(result.snapshot.value);
    if (canUseAccount) {
      unawaited(
        _user.update(updates).catchError((Object error, StackTrace stack) {
          onAncillaryFailure?.call(error, stack);
        }),
      );
      final eventId = '${model.id}-${model.briefing ? 'briefing' : 'started'}';
      _recordOperation({
        'id': eventId,
        'eventId': eventId,
        'schemaVersion': 2,
        'type': model.briefing ? 'briefing_opened' : 'playback_started',
        'occurredAtMs': started.anchorServerMs,
        'sessionId': model.id,
        'phase': 'server_approval',
        'deviceId': model.updatedByDeviceId,
        'deviceRole': 'controller',
        'appVersion': appVersion,
        'workoutId': model.workoutSnapshot['id'],
        'workoutName': model.workoutSnapshot['name'],
        'scheduled': scheduled,
        'scheduledAtMs': scheduledAtMs,
        'targetDeviceIds': model.targetDeviceIds,
        'targetDeviceNames': {
          for (final id in model.targetDeviceIds)
            if (devices is Map &&
                devices[id] is Map &&
                devices[id]['name'] is String)
              id: devices[id]['name'],
        },
        'targetDeviceVersions': {
          for (final id in model.targetDeviceIds)
            if (devices is Map &&
                devices[id] is Map &&
                devices[id]['appVersion'] is String)
              id: devices[id]['appVersion'],
        },
      });
    }
    return started;
  }

  Future<PlaybackSessionModel> update({
    required String? status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
    bool requireBriefing = false,
    bool finishTimer = false,
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
              finishTimer: finishTimer,
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
          if (finishTimer) json['timerCompleted'] = true;
          if (stepIndex != null || status == 'completed') {
            json['timerCompleted'] = false;
          }
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
    final confirmed = _decode(result.snapshot.value);
    final eventId = shouldRecordStart
        ? '$expectedSessionId-started'
        : shouldRecordCompletion
        ? '$expectedSessionId-completed'
        : commandId;
    _recordOperation({
      'id': eventId,
      'eventId': eventId,
      'schemaVersion': 2,
      'type': shouldRecordStart
          ? 'playback_started'
          : shouldRecordCompletion
          ? 'playback_completed'
          : 'command_approved',
      'occurredAtMs': confirmed.anchorServerMs,
      'sessionId': expectedSessionId,
      'phase': 'server_approval',
      'deviceId': deviceId,
      'deviceRole': 'controller',
      'appVersion': appVersion,
      'workoutId': workoutId,
      'workoutName': workoutName,
      'targetDeviceIds': confirmed.targetDeviceIds,
      'scheduled': false,
    });
    return _decode(result.snapshot.value);
  }

  // .info is SDK-local metadata. get() makes a server read on Apple platforms
  // and can fail with permission-denied even when the client is connected.
  Future<int> _serverOffset() =>
      watchServerTimeOffset().first.timeout(const Duration(seconds: 3));

  bool get canUseAccount => !_disposed && isCurrentAccount?.call() != false;

  void _ensureStartAccount() {
    if (!canUseAccount) {
      throw const PlaybackFailure(
        'start_cancelled',
        '계정 연결이 변경되어 수업 시작을 취소했어요.',
      );
    }
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
