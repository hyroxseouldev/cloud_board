import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_session_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/repositories/playback_repository.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';

part 'playback_repository_impl.g.dart';

const realtimeDatabaseUrl = cloudBoardRealtimeDatabaseUrl;

class PlaybackRepositoryImpl implements PlaybackRepository {
  const PlaybackRepositoryImpl(this._dataSource, this._local, this._ownerId);

  final PlaybackRealtimeDataSource _dataSource;
  final PlaybackSessionLocalDataSource _local;
  final String? _ownerId;

  @override
  Stream<PlaybackSession?> watchActive() async* {
    // Owner resolution is asynchronous at startup. Do not erase an offline
    // checkpoint while authentication / display pairing is still resolving.
    if (_ownerId == null) {
      yield null;
      return;
    }
    var cached = await _local.load();
    if (cached?.ownerId != _ownerId) {
      cached = null;
      await _local.clear();
    }
    if (cached != null) yield cached.toEntity();

    await for (final remote in _dataSource.watchActive()) {
      if (remote == null) {
        cached = null;
        await _local.clear();
        yield null;
        continue;
      }
      cached = remote;
      // Persistence is ordered by the shared data source, but does not delay
      // delivery of a remote pause/seek to the display.
      unawaited(
        _local.save(remote).catchError((Object error, StackTrace stack) {
          debugPrint('Playback checkpoint failed: $error\n$stack');
        }),
      );
      yield remote.toEntity();
    }
  }

  @override
  Stream<int> watchServerTimeOffset() => _dataSource.watchServerTimeOffset();

  @override
  Stream<bool> watchConnected() => _dataSource.watchConnected();

  @override
  Future<void> recover({required bool restartTransport}) async {
    final fresh = await _dataSource.recover(restartTransport: restartTransport);
    if (fresh == null) {
      await _local.clear();
    } else {
      await _local.save(fresh);
    }
  }

  @override
  Future<bool> hasRunningSession() => _dataSource.hasRunningSession();

  @override
  Future<PlaybackSession> start({
    required Workout workout,
    required List<String> targetDeviceIds,
    required int stepIndex,
    required int durationMs,
    required String deviceId,
    bool scheduled = false,
    bool briefing = false,
    int? scheduledAtMs,
  }) async {
    final ownerId = _ownerId;
    if (ownerId == null) throw StateError('로그인이 필요합니다.');
    final sessionId =
        'session-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final model = PlaybackSessionModel.fromWorkout(
      id: sessionId,
      ownerId: ownerId,
      zoneId: 'main',
      targetDeviceIds: targetDeviceIds,
      workout: workout,
      stepIndex: stepIndex,
      durationMs: durationMs,
      deviceId: deviceId,
      briefing: briefing,
    );
    final started = await _dataSource.start(
      model,
      scheduled: scheduled,
      scheduledAtMs: scheduledAtMs,
    );
    await _local.save(started);
    return started.toEntity();
  }

  @override
  Future<void> pause({required int remainingMs, required String deviceId}) =>
      _update(
        status: PlaybackStatus.paused.name,
        remainingMs: remainingMs,
        deviceId: deviceId,
      );

  @override
  Future<void> resume({required String deviceId}) =>
      _update(status: PlaybackStatus.playing.name, deviceId: deviceId);

  @override
  Future<void> begin({required String deviceId}) async {
    final session = await _local.load();
    if (session == null) throw StateError('진행 중인 수업이 없습니다.');
    await _update(
      status: PlaybackStatus.playing.name,
      deviceId: deviceId,
      startDelayMs:
          session.toEntity().workout.countdownSeconds.clamp(0, 60) * 1000,
      requireBriefing: true,
    );
  }

  @override
  Future<void> seek({
    required int stepIndex,
    required int durationMs,
    required String deviceId,
  }) => _update(
    status: null,
    stepIndex: stepIndex,
    remainingMs: durationMs,
    deviceId: deviceId,
  );

  @override
  Future<void> complete({required String deviceId}) => _update(
    status: PlaybackStatus.completed.name,
    remainingMs: 0,
    deviceId: deviceId,
  );

  Future<void> _update({
    required String? status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
    bool requireBriefing = false,
  }) async {
    final expected = await _local.load();
    if (expected == null) throw StateError('진행 중인 수업이 없습니다.');
    await _dataSource.update(
      status: status,
      deviceId: deviceId,
      stepIndex: stepIndex,
      remainingMs: remainingMs,
      startDelayMs: startDelayMs,
      requireBriefing: requireBriefing,
      expectedSessionId: expected.id,
      expectedRevision: expected.revision,
    );
    // The confirmed stream owns checkpoints; a late response must not restore
    // a session that was replaced or ended while this command was in flight.
  }
}

@Riverpod(keepAlive: true)
PlaybackRepository playbackRepository(Ref ref) {
  final auth = FirebaseAuth.instance;
  final ownerId = ref.watch(accountOwnerIdProvider).value;
  final database = FirebaseDatabase.instanceFor(
    app: auth.app,
    databaseURL: realtimeDatabaseUrl,
  );
  final source = PlaybackRealtimeDataSource(
    database,
    ownerId,
    serverRead: (path) async {
      final user = auth.currentUser;
      if (user == null || user.uid != ownerId) {
        throw StateError('로그인 계정을 확인해 주세요.');
      }
      final token = await user.getIdToken().timeout(const Duration(seconds: 6));
      if (token == null) throw StateError('인증을 확인해 주세요.');
      final client = http.Client();
      try {
        final response = await client
            .get(
              Uri.parse('$realtimeDatabaseUrl/$path.json')
                  .replace(queryParameters: {'auth': token}),
            )
            .timeout(const Duration(seconds: 6));
        if (auth.currentUser?.uid != user.uid) {
          throw StateError('로그인 계정이 변경되었습니다.');
        }
        if (response.statusCode != 200) {
          throw StateError('최신 수업 상태를 확인하지 못했습니다.');
        }
        return jsonDecode(response.body);
      } on http.ClientException {
        // ClientException may include the authenticated URL; never expose it.
        throw StateError('네트워크 연결을 확인하고 다시 시도해 주세요.');
      } finally {
        client.close();
      }
    },
  );
  ref.onDispose(source.dispose);
  return PlaybackRepositoryImpl(
    source,
    ref.watch(playbackSessionLocalDataSourceProvider),
    ownerId,
  );
}
