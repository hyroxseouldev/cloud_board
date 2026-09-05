import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../device/data/repositories/device_mode_repository_impl.dart';
import '../../../workouts/domain/entities/workout.dart';
import '../../data/repositories/playback_repository_impl.dart';
import '../../domain/entities/playback_session.dart';
import '../../domain/usecases/playback_actions.dart';

part 'playback_session_controller.g.dart';

@Riverpod(keepAlive: true)
Stream<PlaybackSession?> activePlaybackSession(Ref ref) =>
    ref.watch(playbackRepositoryProvider).watchActive();

@Riverpod(keepAlive: true)
Stream<int> serverTimeOffset(Ref ref) =>
    ref.watch(playbackRepositoryProvider).watchServerTimeOffset();

@Riverpod(keepAlive: true)
class PlaybackActionController extends _$PlaybackActionController {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  Future<String?> start({
    required Workout workout,
    required int stepIndex,
    required int durationMs,
  }) async {
    state = const AsyncLoading();
    PlaybackSession? session;
    state = await AsyncValue.guard(() async {
      session = await ref
          .read(playbackActionsProvider)
          .start(
            workout: workout,
            stepIndex: stepIndex,
            durationMs: durationMs,
            deviceId: await ref.read(deviceIdProvider.future),
          );
      return '재생을 시작했습니다.';
    });
    return state.hasError ? null : session?.id;
  }

  Future<bool> pause(int remainingMs) => _run(
    '일시정지했습니다.',
    (actions, deviceId) =>
        actions.pause(remainingMs: remainingMs, deviceId: deviceId),
  );

  Future<bool> resume() => _run(
    '재생을 계속합니다.',
    (actions, deviceId) => actions.resume(deviceId: deviceId),
  );

  Future<bool> seek({required int stepIndex, required int durationMs}) => _run(
    '재생 위치를 이동했습니다.',
    (actions, deviceId) => actions.seek(
      stepIndex: stepIndex,
      durationMs: durationMs,
      deviceId: deviceId,
    ),
  );

  Future<bool> complete() => _run(
    '재생을 종료했습니다.',
    (actions, deviceId) => actions.complete(deviceId: deviceId),
  );

  Future<bool> syncStep({
    required int stepIndex,
    required int durationMs,
  }) async {
    try {
      await ref
          .read(playbackActionsProvider)
          .seek(
            stepIndex: stepIndex,
            durationMs: durationMs,
            deviceId: await ref.read(deviceIdProvider.future),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> syncComplete() async {
    try {
      await ref
          .read(playbackActionsProvider)
          .complete(deviceId: await ref.read(deviceIdProvider.future));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _run(
    String successMessage,
    Future<void> Function(PlaybackActions actions, String deviceId) action,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await action(
        ref.read(playbackActionsProvider),
        await ref.read(deviceIdProvider.future),
      );
      return successMessage;
    });
    return !state.hasError;
  }
}
