import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../workouts/domain/entities/workout.dart';
import '../../data/repositories/playback_repository_impl.dart';
import '../entities/playback_session.dart';
import '../repositories/playback_repository.dart';

part 'playback_actions.g.dart';

class PlaybackActions {
  const PlaybackActions(this._repository);
  final PlaybackRepository _repository;

  Future<PlaybackSession> start({
    required Workout workout,
    required int stepIndex,
    required int durationMs,
    required String deviceId,
  }) => _repository.start(
    workout: workout,
    stepIndex: stepIndex,
    durationMs: durationMs,
    deviceId: deviceId,
  );

  Future<void> pause({required int remainingMs, required String deviceId}) =>
      _repository.pause(remainingMs: remainingMs, deviceId: deviceId);

  Future<void> resume({required String deviceId}) =>
      _repository.resume(deviceId: deviceId);

  Future<void> seek({
    required int stepIndex,
    required int durationMs,
    required String deviceId,
  }) => _repository.seek(
    stepIndex: stepIndex,
    durationMs: durationMs,
    deviceId: deviceId,
  );

  Future<void> complete({required String deviceId}) =>
      _repository.complete(deviceId: deviceId);
}

@riverpod
PlaybackActions playbackActions(Ref ref) =>
    PlaybackActions(ref.watch(playbackRepositoryProvider));
