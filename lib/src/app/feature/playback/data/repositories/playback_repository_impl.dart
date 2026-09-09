import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    var cached = await _local.load();
    if (cached?.ownerId != _ownerId) {
      cached = null;
      await _local.clear();
    }
    yield cached?.toEntity();

    await for (final remote in _dataSource.watchActive()) {
      if (remote == null) {
        if (cached == null) yield null;
        continue;
      }
      cached = remote;
      await _local.save(remote);
      yield remote.toEntity();
    }
  }

  @override
  Stream<int> watchServerTimeOffset() => _dataSource.watchServerTimeOffset();

  @override
  Stream<bool> watchConnected() => _dataSource.watchConnected();

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
  Future<void> begin({required String deviceId}) => _update(
    status: PlaybackStatus.playing.name,
    deviceId: deviceId,
    startDelayMs: 3000,
    requireBriefing: true,
  );

  @override
  Future<void> seek({
    required int stepIndex,
    required int durationMs,
    required String deviceId,
  }) => _update(
    status: PlaybackStatus.playing.name,
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
    required String status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
    bool requireBriefing = false,
  }) async {
    await _local.update(
      status: status,
      deviceId: deviceId,
      stepIndex: stepIndex,
      remainingMs: remainingMs,
      startDelayMs: startDelayMs,
    );
    try {
      final updated = await _dataSource
          .update(
            status: status,
            deviceId: deviceId,
            stepIndex: stepIndex,
            remainingMs: remainingMs,
            startDelayMs: startDelayMs,
            requireBriefing: requireBriefing,
          )
          .timeout(const Duration(seconds: 2));
      await _local.save(updated);
    } on TimeoutException {
      // Firebase keeps the write pending; local playback must continue offline.
    }
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
  return PlaybackRepositoryImpl(
    PlaybackRealtimeDataSource(database, ownerId),
    PlaybackSessionLocalDataSource(SharedPreferencesAsync()),
    ownerId,
  );
}
