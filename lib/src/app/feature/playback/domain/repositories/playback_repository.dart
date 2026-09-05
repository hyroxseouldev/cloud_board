import '../../../workouts/domain/entities/workout.dart';
import '../entities/playback_session.dart';

abstract interface class PlaybackRepository {
  Stream<PlaybackSession?> watchActive();
  Stream<int> watchServerTimeOffset();
  Future<PlaybackSession> start({
    required Workout workout,
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
