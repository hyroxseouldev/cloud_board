import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/entitlement_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/usecases/playback_actions.dart';

part 'playback_session_controller.g.dart';

@Riverpod(keepAlive: true)
Stream<PlaybackSession?> activePlaybackSession(Ref ref) =>
    ref.watch(playbackRepositoryProvider).watchActive();

@Riverpod(keepAlive: true)
Stream<int> serverTimeOffset(Ref ref) =>
    ref.watch(playbackRepositoryProvider).watchServerTimeOffset();

@Riverpod(keepAlive: true)
Stream<bool> playbackConnection(Ref ref) =>
    ref.watch(playbackRepositoryProvider).watchConnected();

@Riverpod(keepAlive: true)
class PlaybackActionController extends _$PlaybackActionController {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  Future<String?> start({
    required Workout workout,
    required int stepIndex,
    required int durationMs,
    required List<String> targetDeviceIds,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    PlaybackSession? session;
    state = await AsyncValue.guard(() async {
      final uid = ref.read(firebaseAccountUserProvider).value?.uid;
      final entitlement = ref.read(storeEntitlementProvider).value;
      final serverNow =
          DateTime.now().millisecondsSinceEpoch +
          (ref.read(serverTimeOffsetProvider).value ?? 0);
      if (entitlement?.allowsNewClass(uid, serverNow) != true) {
        throw StateError(
          '웹에서 계정 연결과 체험 또는 구독 상태를 확인해 주세요. 프로그램 편집과 미리보기는 계속 사용할 수 있습니다.',
        );
      }
      session = await ref
          .read(playbackActionsProvider)
          .start(
            workout: workout,
            targetDeviceIds: targetDeviceIds,
            stepIndex: stepIndex,
            durationMs: durationMs,
            deviceId: await ref.read(deviceIdProvider.future),
            briefing: false,
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

  Future<bool> begin() => _run(
    '수업을 시작합니다.',
    (actions, deviceId) => actions.begin(deviceId: deviceId),
  );

  Future<bool> seek({required int stepIndex, required int durationMs}) => _run(
    '재생 위치를 이동했습니다.',
    (actions, deviceId) => actions.seek(
      stepIndex: stepIndex,
      durationMs: durationMs,
      deviceId: deviceId,
    ),
  );

  Future<bool>? _completion;
  // Natural completion and the screen exit can arrive in the same frame.
  Future<bool> complete() => _completion ??= _run(
    '재생을 종료했습니다.',
    (actions, deviceId) => actions.complete(deviceId: deviceId),
  ).whenComplete(() => _completion = null);

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

  Future<bool> syncComplete() => complete();

  Future<bool> _run(
    String successMessage,
    Future<void> Function(PlaybackActions actions, String deviceId) action,
  ) async {
    if (state.isLoading) return false;
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
