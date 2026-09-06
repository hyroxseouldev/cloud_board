import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_session_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/repositories/playback_repository.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';

part 'playback_repository_impl.g.dart';

const realtimeDatabaseUrl =
    'https://cloud-board-stationd-default-rtdb.asia-southeast1.firebasedatabase.app';

class PlaybackRepositoryImpl implements PlaybackRepository {
  const PlaybackRepositoryImpl(this._dataSource, this._local, this._auth);

  final PlaybackRealtimeDataSource _dataSource;
  final PlaybackSessionLocalDataSource _local;
  final FirebaseAuth _auth;

  @override
  Stream<PlaybackSession?> watchActive() async* {
    final userId = _auth.currentUser?.uid;
    var cached = await _local.load();
    if (cached?.ownerId != userId) {
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
  Future<PlaybackSession> start({
    required Workout workout,
    required String zoneId,
    required int stepIndex,
    required int durationMs,
    required String deviceId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final sessionId =
        'session-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final model = PlaybackSessionModel.fromWorkout(
      id: sessionId,
      ownerId: user.uid,
      zoneId: zoneId,
      workout: workout,
      stepIndex: stepIndex,
      durationMs: durationMs,
      deviceId: deviceId,
    );
    final started = await _dataSource.start(model);
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
  }) async {
    await _local.update(
      status: status,
      deviceId: deviceId,
      stepIndex: stepIndex,
      remainingMs: remainingMs,
    );
    try {
      final updated = await _dataSource
          .update(
            status: status,
            deviceId: deviceId,
            stepIndex: stepIndex,
            remainingMs: remainingMs,
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
  final database = FirebaseDatabase.instanceFor(
    app: auth.app,
    databaseURL: realtimeDatabaseUrl,
  );
  return PlaybackRepositoryImpl(
    PlaybackRealtimeDataSource(database, auth),
    PlaybackSessionLocalDataSource(SharedPreferencesAsync()),
    auth,
  );
}
