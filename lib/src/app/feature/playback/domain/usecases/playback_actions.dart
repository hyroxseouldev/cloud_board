import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/display_preparation_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_preferences_actions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/repositories/playback_repository.dart';

part 'playback_actions.g.dart';

class PlaybackActions {
  const PlaybackActions(
    this._repository, {
    this.preferences,
    this.preparation,
    this.isCurrent,
  });
  final bool Function()? isCurrent;
  final DisplayPreparationActions? preparation;
  final WorkoutPreferencesActions? preferences;
  final PlaybackRepository _repository;

  Future<void> recover({required bool restartTransport}) =>
      _repository.recover(restartTransport: restartTransport);

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
    DisplayPreparationProof? preparationProof,
    void Function()? ensureCurrent,
    void Function(String stage)? onStage,
  }) async {
    void checkCurrent() {
      if (isCurrent?.call() == false) {
        throw const PlaybackFailure(
          'start_cancelled',
          '수업 연결이 변경되어 시작을 취소했어요. 다시 확인해 주세요.',
        );
      }
      ensureCurrent?.call();
    }

    checkCurrent();
    onStage?.call('preferences');
    final effective = await preferences?.apply(workout, fresh: true) ?? workout;
    checkCurrent();
    onStage?.call('preparation');
    await preparation?.verifyStart(
      effective,
      targetDeviceIds,
      preparationProof,
    );
    checkCurrent();
    onStage?.call('session');
    return _repository.start(
      workout: effective,
      targetDeviceIds: targetDeviceIds,
      stepIndex: stepIndex,
      durationMs: durationMs,
      deviceId: deviceId,
      scheduled: scheduled,
      briefing: briefing,
      scheduledAtMs: scheduledAtMs,
      ensureCurrent: checkCurrent,
    );
  }

  Future<void> pause({required int remainingMs, required String deviceId}) =>
      _repository.pause(remainingMs: remainingMs, deviceId: deviceId);

  Future<void> finishTimer({required String deviceId}) =>
      _repository.finishTimer(deviceId: deviceId);

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
PlaybackActions playbackActions(Ref ref) {
  var current = true;
  ref.onDispose(() => current = false);
  return PlaybackActions(
    ref.watch(playbackRepositoryProvider),
    preferences: ref.watch(workoutPreferencesActionsProvider),
    preparation: ref.watch(displayPreparationActionsProvider),
    isCurrent: () => current,
  );
}
