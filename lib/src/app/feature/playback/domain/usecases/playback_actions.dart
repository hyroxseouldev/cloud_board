import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/repositories/playback_repository.dart';

part 'playback_actions.g.dart';

class PlaybackActions {
  const PlaybackActions(this._repository);
  final PlaybackRepository _repository;

  Future<bool> hasRunningSession() => _repository.hasRunningSession();

  Future<PlaybackSession> start({
    required Workout workout,
    required List<String> targetDeviceIds,
    required int stepIndex,
    required int durationMs,
    required String deviceId,
    bool scheduled = false,
    bool briefing = false,
    int? scheduledAtMs,
  }) => _repository.start(
    workout: workout,
    targetDeviceIds: targetDeviceIds,
    stepIndex: stepIndex,
    durationMs: durationMs,
    deviceId: deviceId,
    scheduled: scheduled,
    briefing: briefing,
    scheduledAtMs: scheduledAtMs,
  );

  Future<void> pause({required int remainingMs, required String deviceId}) =>
      _repository.pause(remainingMs: remainingMs, deviceId: deviceId);

  Future<void> resume({required String deviceId}) =>
      _repository.resume(deviceId: deviceId);

  Future<void> begin({required String deviceId}) =>
      _repository.begin(deviceId: deviceId);

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
