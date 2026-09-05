import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../workouts/domain/entities/workout.dart';
import '../../domain/entities/playback_session.dart';
import '../../domain/repositories/playback_repository.dart';
import '../datasources/playback_realtime_data_source.dart';
import '../models/playback_session_model.dart';

part 'playback_repository_impl.g.dart';

const realtimeDatabaseUrl =
    'https://cloud-board-stationd-default-rtdb.asia-southeast1.firebasedatabase.app';

class PlaybackRepositoryImpl implements PlaybackRepository {
  const PlaybackRepositoryImpl(this._dataSource, this._auth);

  final PlaybackRealtimeDataSource _dataSource;
  final FirebaseAuth _auth;

  @override
  Stream<PlaybackSession?> watchActive() =>
      _dataSource.watchActive().map((model) => model?.toEntity());

  @override
  Stream<int> watchServerTimeOffset() => _dataSource.watchServerTimeOffset();

  @override
  Future<PlaybackSession> start({
    required Workout workout,
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
      workout: workout,
      stepIndex: stepIndex,
      durationMs: durationMs,
      deviceId: deviceId,
    );
    return (await _dataSource.start(model)).toEntity();
  }

  @override
  Future<void> pause({required int remainingMs, required String deviceId}) =>
      _dataSource.update(
        status: PlaybackStatus.paused.name,
        remainingMs: remainingMs,
        deviceId: deviceId,
      );

  @override
  Future<void> resume({required String deviceId}) => _dataSource.update(
    status: PlaybackStatus.playing.name,
    deviceId: deviceId,
  );

  @override
  Future<void> seek({
    required int stepIndex,
    required int durationMs,
    required String deviceId,
  }) => _dataSource.update(
    status: PlaybackStatus.playing.name,
    stepIndex: stepIndex,
    remainingMs: durationMs,
    deviceId: deviceId,
  );

  @override
  Future<void> complete({required String deviceId}) => _dataSource.update(
    status: PlaybackStatus.completed.name,
    remainingMs: 0,
    deviceId: deviceId,
  );
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
    auth,
  );
}
