import 'package:cloud_board/src/app/core/observability/playback_ack.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
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
Stream<PlaybackSession?> activePlaybackSession(Ref ref) => ref
    .watch(playbackRepositoryProvider)
    .watchActive()
    .handleError((Object error, StackTrace stack) {
      ref
          .read(errorReporterProvider)
          .capture(error, stack, action: 'playback.stream');
      Error.throwWithStackTrace(error, stack);
    });

@Riverpod(keepAlive: true)
Stream<int> serverTimeOffset(Ref ref) =>
    ref.watch(playbackRepositoryProvider).watchServerTimeOffset();

@Riverpod(keepAlive: true)
Stream<bool> playbackConnection(Ref ref) =>
    ref.watch(playbackRepositoryProvider).watchConnected();

@Riverpod(keepAlive: true)
class PlaybackActionController extends _$PlaybackActionController {
  Timer? _transportCooldown;
  void Function()? _cancelAck;

  bool get canSendTransportCommand =>
      !state.isLoading && !(_transportCooldown?.isActive ?? false);

  @override
  AsyncValue<String?> build() {
    ref.onDispose(() {
      _transportCooldown?.cancel();
      _cancelAck?.call();
    });
    return const AsyncData(null);
  }

  Future<String?> start({
    required Workout workout,
    required int stepIndex,
    required int durationMs,
    required List<String> targetDeviceIds,
    DisplayPreparationProof? preparationProof,
  }) async {
    if (state.isLoading) return null;
    final attempt = ref
        .read(operationTelemetryProvider)
        .start('playback.control.submit');
    state = const AsyncLoading();
    PlaybackSession? session;
    final result = await AsyncValue.guard(() async {
      final uid = ref.read(firebaseAccountUserProvider).value?.uid;
      final entitlement = ref.read(storeEntitlementProvider).value;
      final serverNow =
          DateTime.now().millisecondsSinceEpoch +
          (ref.read(serverTimeOffsetProvider).value ?? 0);
      if (entitlement?.allowsNewClass(uid, serverNow) != true) {
        throw StateError(
          '프로필의 센터 정보 · 온보딩에서 무료 체험을 시작하거나 이용 상태를 확인해 주세요. 프로그램 편집과 미리보기는 계속 사용할 수 있습니다.',
        );
      }
      session = await ref
          .read(playbackActionsProvider)
          .start(
            workout: workout,
            targetDeviceIds: targetDeviceIds,
            preparationProof: preparationProof,
            stepIndex: stepIndex,
            durationMs: durationMs,
            deviceId: await ref.read(deviceIdProvider.future),
            briefing: false,
          );
      return '재생을 시작했습니다.';
    });
    if (result.hasError) {
      attempt.failure(
        result.error is PlaybackFailure
            ? (result.error! as PlaybackFailure).code
            : result.error,
      );
    } else {
      attempt.success();
    }
    if (!ref.mounted) return null;
    if (!result.hasError && session != null) {
      _watchDisplayAcknowledgement(
        session!,
        revision: session!.revision,
        deviceId: session!.updatedByDeviceId,
      );
    }
    state = result;
    _reportResult(
      'playback.start',
      result,
      context: {
        'role': 'controller',
        'workoutId': workout.id,
        'stepIndex': stepIndex,
        'moduleCount': workout.modules.length,
        'connected': ref.read(playbackConnectionProvider).value,
      },
    );
    return result.hasError ? null : session?.id;
  }

  Future<bool> pause(int remainingMs) => _run(
    '일시정지했습니다.',
    'playback.pause',
    (actions, deviceId) =>
        actions.pause(remainingMs: remainingMs, deviceId: deviceId),
    throttle: true,
  );

  Future<bool> finishTimer() => _run(
    '운동을 완료했습니다.',
    'playback.finishTimer',
    (actions, deviceId) => actions.finishTimer(deviceId: deviceId),
    throttle: true,
  );

  Future<bool> resume() => _run(
    '재생을 계속합니다.',
    'playback.resume',
    (actions, deviceId) => actions.resume(deviceId: deviceId),
    throttle: true,
  );

  Future<bool> begin() => _run(
    '수업을 시작합니다.',
    'playback.begin',
    (actions, deviceId) => actions.begin(deviceId: deviceId),
  );

  Future<bool> seek({required int stepIndex, required int durationMs}) => _run(
    '재생 위치를 이동했습니다.',
    'playback.seek',
    (actions, deviceId) => actions.seek(
      stepIndex: stepIndex,
      durationMs: durationMs,
      deviceId: deviceId,
    ),
    throttle: true,
  );

  Future<bool>? _completion;
  // Natural completion and the screen exit can arrive in the same frame.
  Future<bool> complete() => _completion ??= _run(
    '재생을 종료했습니다.',
    'playback.complete',
    (actions, deviceId) => actions.complete(deviceId: deviceId),
  ).whenComplete(() => _completion = null);

  Future<bool> syncStep({
    required int stepIndex,
    required int durationMs,
  }) async {
    return seek(stepIndex: stepIndex, durationMs: durationMs);
  }

  Future<bool> syncComplete() => complete();

  Future<bool> _run(
    String successMessage,
    String actionName,
    Future<void> Function(PlaybackActions actions, String deviceId) action, {
    bool throttle = false,
  }) async {
    if (state.isLoading ||
        (throttle && !canSendTransportCommand) ||
        !ref.read(playbackRecoveryControllerProvider).hasValue) {
      return false;
    }
    if (throttle) {
      // Accept the first tap immediately and drop rapid follow-up commands.
      // Loading continues to guard requests that take longer than this window.
      _transportCooldown?.cancel();
      _transportCooldown = Timer(const Duration(milliseconds: 350), () {});
    }
    final attempt = ref
        .read(operationTelemetryProvider)
        .start('playback.control.submit');
    final expectedSession = ref.read(activePlaybackSessionProvider).value;
    final reporter = ref.read(errorReporterProvider);
    final context = _context();
    final elapsed = Stopwatch()..start();
    context['expectedRevision'] = expectedSession?.revision;
    reporter.breadcrumb(actionName, context);
    String? commandDeviceId;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final actions = ref.read(playbackActionsProvider);
      final deviceId = await ref.read(deviceIdProvider.future);
      commandDeviceId = deviceId;
      if (!ref.mounted) {
        throw const PlaybackFailure('session_changed', '계정 연결이 변경되었습니다.');
      }
      final current = ref.read(activePlaybackSessionProvider).value;
      if (expectedSession?.id != current?.id ||
          expectedSession?.revision != current?.revision) {
        throw PlaybackFailure(
          'revision_conflict',
          '수업 상태가 변경되었습니다. 최신 상태를 확인해 주세요.',
          expectedRevision: expectedSession?.revision,
          observedRevision: current?.revision,
        );
      }
      await action(actions, deviceId);
      return successMessage;
    });
    if (result.hasError) {
      attempt.failure(
        result.error is PlaybackFailure
            ? (result.error! as PlaybackFailure).code
            : result.error,
      );
    } else {
      attempt.success();
    }
    if (!ref.mounted) return false;
    if (!result.hasError &&
        expectedSession != null &&
        commandDeviceId != null) {
      _watchDisplayAcknowledgement(
        expectedSession,
        revision: expectedSession.revision + 1,
        deviceId: commandDeviceId!,
      );
    }
    state = result;
    _reportResult(
      actionName,
      result,
      context: {...context, 'elapsedMs': elapsed.elapsedMilliseconds},
    );
    if (result.hasError && throttle) _transportCooldown?.cancel();
    if (result.error case final PlaybackFailure failure
        when failure.needsRefresh) {
      // Refresh only. Replaying an obsolete seek/pause can undo the other operator.
      await ref
          .read(playbackRecoveryControllerProvider.notifier)
          .recover(restartTransport: false);
    }
    return !result.hasError;
  }

  // At most one passive observer; a later accepted control supersedes it.
  // It never delays commands or retries a command after a missing TV response.
  void _watchDisplayAcknowledgement(
    PlaybackSession expected, {
    required int revision,
    required String deviceId,
  }) {
    _cancelAck?.call();
    if (expected.targetDeviceIds.isEmpty || !ref.mounted) return;
    final attempt = ref
        .read(operationTelemetryProvider)
        .start('playback.control.ack');
    var done = false;
    final baselineSessionId = ref.read(activePlaybackSessionProvider).value?.id;
    var observedExpectedSession = baselineSessionId == expected.id;
    Timer? timer;
    void Function()? closeSession, closeDevices;
    void finish(PlaybackAckVerdict verdict, [String? failure]) {
      if (done) return;
      done = true;
      timer?.cancel();
      closeSession?.call();
      closeDevices?.call();
      _cancelAck = null;
      if (failure != null) {
        attempt.failure(failure);
      } else if (verdict == PlaybackAckVerdict.success) {
        attempt.success();
      } else {
        attempt.cancel();
      }
    }

    void check() {
      if (done) return;
      if (!ref.mounted) {
        finish(PlaybackAckVerdict.cancelled);
        return;
      }
      final active = ref.read(activePlaybackSessionProvider);
      final deviceState = ref.read(displayDevicesProvider);
      if (active.hasError || deviceState.hasError) {
        finish(PlaybackAckVerdict.cancelled);
        return;
      }
      if (active.isLoading || deviceState.isLoading) return;
      final session = active.value;
      // A new start can resolve before its stream replaces the previous class.
      // Wait through that initial baseline, but cancel for any later session.
      if (session?.id == expected.id) observedExpectedSession = true;
      if (!observedExpectedSession && session?.id == baselineSessionId) return;
      final verdict = evaluatePlaybackAck(
        expectedSessionId: expected.id,
        expectedRevision: revision,
        targetIds: expected.targetDeviceIds.toSet(),
        expectedDeviceId: deviceId,
        currentSessionId: session?.id,
        currentRevision: session?.revision,
        currentDeviceId: session?.updatedByDeviceId,
        currentTargetIds: session?.targetDeviceIds.toSet() ?? const {},
        devices: (deviceState.value ?? const []).map(
          (device) => PlaybackAckDevice(
            device.id,
            device.currentSessionId,
            device.acknowledgedRevision,
            paired: device.paired,
          ),
        ),
      );
      if (verdict != PlaybackAckVerdict.pending) finish(verdict);
    }

    closeSession = ref
        .listen(activePlaybackSessionProvider, (_, _) => check())
        .close;
    closeDevices = ref.listen(displayDevicesProvider, (_, _) => check()).close;
    timer = Timer(
      const Duration(seconds: 12),
      () => finish(PlaybackAckVerdict.pending, 'timeout'),
    );
    _cancelAck = () => finish(PlaybackAckVerdict.cancelled);
    check();
  }

  Map<String, Object?> _context() {
    final session = ref.read(activePlaybackSessionProvider).value;
    return {
      'role': 'controller',
      'sessionId': session?.id,
      'workoutId': session?.workout.id,
      'observedRevision': session?.revision,
      'stepIndex': session?.stepIndex,
      'moduleCount': session?.workout.modules.length,
      'status': session?.status.name,
      'remainingMs': session?.remainingMs,
      'connected': ref.read(playbackConnectionProvider).value,
    };
  }

  void _reportResult(
    String action,
    AsyncValue<String?> result, {
    Map<String, Object?>? context,
  }) {
    if (result.hasError) {
      ref
          .read(errorReporterProvider)
          .capture(
            result.error!,
            result.stackTrace ?? StackTrace.current,
            action: action,
            context: context ?? _context(),
          );
    }
  }
}

/// Blocks controller commands until a foreground server handshake completes.
@Riverpod(keepAlive: true)
class PlaybackRecoveryController extends _$PlaybackRecoveryController {
  int _epoch = 0;
  bool _running = false;
  bool _retryQueued = false;

  @override
  AsyncValue<void> build() => const AsyncData(null);

  void suspend() {
    ++_epoch;
    state = const AsyncLoading();
  }

  Future<void> recover({bool restartTransport = true}) async {
    if (_running) {
      _retryQueued = true;
      return;
    }
    _running = true;
    final epoch = _epoch;
    final elapsed = Stopwatch()..start();
    state = const AsyncLoading();
    final actionsSubscription = ref.listen(playbackActionsProvider, (_, _) {});
    try {
      final actions = ref.read(playbackActionsProvider);
      await actions.recover(restartTransport: restartTransport);
      debugPrint(
        'Playback recovery: server confirmed in ${elapsed.elapsedMilliseconds}ms',
      );
      if (!ref.mounted || epoch != _epoch) return;
      if (!identical(actions, ref.read(playbackActionsProvider))) {
        throw StateError('계정이 변경되었습니다. 다시 확인해 주세요.');
      }
      ref.invalidate(activePlaybackSessionProvider);
      ref.invalidate(serverTimeOffsetProvider);
      final received = Completer<void>();
      final subscription = ref.listen(activePlaybackSessionProvider, (
        previous,
        next,
      ) {
        if (received.isCompleted) return;
        if (next.hasError) {
          received.completeError(next.error!, next.stackTrace);
        } else if (!next.isLoading) {
          received.complete();
        }
      }, fireImmediately: true);
      try {
        await received.future.timeout(const Duration(seconds: 6));
      } finally {
        subscription.close();
      }
      if (ref.mounted && epoch == _epoch) state = const AsyncData(null);
    } catch (error, stack) {
      if (ref.mounted && epoch == _epoch) {
        state = AsyncError(error, stack);
        ref
            .read(errorReporterProvider)
            .capture(
              error,
              stack,
              action: 'playback.recover',
              context: {'elapsedMs': elapsed.elapsedMilliseconds},
            );
      }
    } finally {
      actionsSubscription.close();
      _running = false;
      if (ref.mounted) {
        debugPrint(
          'Playback recovery: completed in ${elapsed.elapsedMilliseconds}ms; ready=${state.hasValue}',
        );
      }
      if (_retryQueued && ref.mounted) {
        _retryQueued = false;
        unawaited(recover());
      }
    }
  }
}
