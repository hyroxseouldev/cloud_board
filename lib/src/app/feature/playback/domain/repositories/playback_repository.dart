import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';

abstract interface class PlaybackRepository {
  Stream<PlaybackSession?> watchActive();
  Stream<int> watchServerTimeOffset();
  Stream<bool> watchConnected();
  Future<PlaybackSession> start({
    required Workout workout,
    required String zoneId,
    required int stepIndex,
    required int durationMs,
    required String deviceId,
  });
  Future<void> pause({required int remainingMs, required String deviceId});
  Future<void> resume({required String deviceId});
  Future<void> seek({
    required int stepIndex,
    required int durationMs,
    required String deviceId,
  });
  Future<void> complete({required String deviceId});
}
