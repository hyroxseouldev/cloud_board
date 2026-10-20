import 'package:cloud_board/src/app/feature/operations/presentation/controllers/operation_event_recorder.dart';
import 'package:cloud_board/src/app/core/services/event_id.dart';
import 'package:cloud_board/src/app/core/observability/playback_ack.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';

import 'dart:async';

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
  int _startEpoch = 0;
  int _transportEpoch = 0;

  bool get canSendTransportCommand =>
      !state.isLoading && !(_transportCooldown?.isActive ?? false);

  @override
  AsyncValue<String?> build() {
    ++_startEpoch;
    ++_transportEpoch;
    _completion = null;
    ref.onDispose(() {
      ++_startEpoch;
      ++_transportEpoch;
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
    final epoch = _startEpoch;
    final uid = ref.read(firebaseAccountUserProvider).value?.uid;
    final reporter = ref.read(errorReporterProvider);
    final attempt = ref
        .read(operationTelemetryProvider)
        .start('playback.control.submit');
    var cancelled = false;
    var stage = 'access';
    void Function()? closeActions;
    void Function()? closeAccount;
    void ensureCurrent() {
      if (cancelled || epoch != _startEpoch) {
        throw const PlaybackFailure(
          'start_cancelled',
          '계정이나 수업 연결이 변경되어 시작을 취소했어요. 다시 확인해 주세요.',
        );
      }
    }

    final context = <String, Object?>{
      'role': 'controller',
      'operationId': attempt.id,
      'workoutId': workout.id,
      'stepIndex': stepIndex,
      'moduleCount': workout.modules.length,
      'connected': ref.read(playbackConnectionProvider).value,
    };
    void onStage(String next) {
      stage = next;
      reporter.breadcrumb('playback.start.$next', {
        ...context,
        'startStage': next,
      });
    }

    state = const AsyncLoading();
    PlaybackSession? session;
    late AsyncValue<String?> result;
    try {
      result = await AsyncValue.guard(() async {
        final entitlement = ref.read(storeEntitlementProvider).value;
        final serverNow =
            DateTime.now().millisecondsSinceEpoch +
            (ref.read(serverTimeOffsetProvider).value ?? 0);
        if (uid == null ||
            workout.ownerId != uid ||
            entitlement?.allowsNewClass(uid, serverNow) != true) {
          throw StateError(
            '프로필에서 휴대폰 인증과 이용 상태를 확인해 주세요. 프로그램 편집과 미리보기는 계속 사용할 수 있습니다.',
          );
        }
        // Read alone does not retain an autoDispose provider through either await.
        // Retain its watched dependencies until this entire operation settles.
        final actionsSubscription = ref.listen(playbackActionsProvider, (
          before,
          next,
        ) {
          if (before != null && !identical(before, next)) cancelled = true;
        });
        final accountSubscription = ref.listen(firebaseAccountUserProvider, (
          _,
          next,
        ) {
          if (next.value?.uid != uid) cancelled = true;
        });
        closeActions = actionsSubscription.close;
        closeAccount = accountSubscription.close;
        final actions = ref.read(playbackActionsProvider);
        onStage('device');
        final deviceId = await ref.read(deviceIdProvider.future);
        ensureCurrent();
        session = await actions.start(
          workout: workout,
          targetDeviceIds: List.unmodifiable(targetDeviceIds),
          preparationProof: preparationProof,
          stepIndex: stepIndex,
          durationMs: durationMs,
          deviceId: deviceId,
          briefing: false,
          ensureCurrent: ensureCurrent,
          onStage: onStage,
        );
        reporter.breadcrumb('playback.start.committed', {
          ...context,
          'startStage': 'committed',
          'sessionId': session!.id,
          'expectedRevision': session!.revision,
        });
        return '재생을 시작했습니다.';
      });
    } finally {
      closeActions?.call();
      closeAccount?.call();
    }
    if (result.hasError) {
      final error = result.error;
      attempt.failure(error is PlaybackFailure ? error.code : 'start_$stage');
      final diagnostic = reporter.capture(
        error!,
        result.stackTrace ?? StackTrace.current,
        action: 'playback.start.$stage',
        context: {...context, 'startStage': stage},
      );
      // A changed account must not receive the previous owner's failed start.
      // Keep the operational record linked to the same stage-aware diagnostic.
      if (ref.mounted &&
          epoch == _startEpoch &&
          !cancelled &&
          uid != null &&
          ref.read(firebaseAccountUserProvider).value?.uid == uid) {
        recordOperationEvent(
          ref,
          type: 'command_failed',
          phase: 'server_approval',
          eventId: diagnostic.id,
          errorId: diagnostic.id,
          errorCode: error is PlaybackFailure ? error.code : 'start_$stage',
          workoutId: workout.id,
        );
      }
    } else {
      attempt.success();
    }
    // A navigation change deliberately does not cancel a submitted start: this
    // controller survives routes. Account/provider changes cancel before writes.
    // Once committed, the server session is authoritative; never replay it.
    if (!ref.mounted || epoch != _startEpoch) return null;
    if (!cancelled && !result.hasError && session != null) {
      _watchDisplayAcknowledgement(
        session!,
        revision: session!.revision,
        deviceId: session!.updatedByDeviceId,
      );
    }
    state = result;
    return cancelled || result.hasError ? null : session?.id;
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
  Future<bool> complete() {
    final pending = _completion;
    if (pending != null) return pending;
    late final Future<bool> flight;
    flight =
        _run(
          '재생을 종료했습니다.',
          'playback.complete',
          (actions, deviceId) => actions.complete(deviceId: deviceId),
          awaitDisplayReceipt: false,
        ).whenComplete(() {
          if (identical(_completion, flight)) _completion = null;
        });
    return _completion = flight;
  }

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
    bool awaitDisplayReceipt = true,
  }) async {
    if (state.isLoading ||
        (throttle && !canSendTransportCommand) ||
        !ref.read(playbackRecoveryControllerProvider).hasValue) {
      return false;
    }
    final epoch = ++_transportEpoch;
    final scope = AccountOperationScope.capture(
      ref,
      onInvalidated: () {
        if (!ref.mounted || epoch != _transportEpoch) return;
        ++_transportEpoch;
        _transportCooldown?.cancel();
        _completion = null;
        _cancelAck?.call();
        state = const AsyncData(null);
      },
    );
    if (scope == null) return false;
    try {
      final active = ref.read(activePlaybackSessionProvider);
      if (active.isLoading ||
          active.hasError ||
          (active.value != null && active.value!.ownerId != scope.ownerId)) {
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
      final expectedSession = active.value;
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
        if (!scope.isCurrent || epoch != _transportEpoch) {
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
      // The server result remains authoritative after submission. A cancelled
      // account scope only suppresses stale UI, follow-up reads and event writes.
      if (!scope.isCurrent || epoch != _transportEpoch) return !result.hasError;
      if (!result.hasError) {
        if (!awaitDisplayReceipt) {
          // Existing displays stop acknowledging when the class completes.
          // Server approval is sufficient here; do not invent a TV receipt.
          _cancelAck?.call();
        } else if (expectedSession != null && commandDeviceId != null) {
          _watchDisplayAcknowledgement(
            expectedSession,
            revision: expectedSession.revision + 1,
            deviceId: commandDeviceId!,
          );
        }
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
    } finally {
      scope.close();
    }
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
    final reporter = ref.read(errorReporterProvider);
    final ackContext = <String, Object?>{
      'operationId': attempt.id,
      'sessionId': expected.id,
      'expectedRevision': revision,
      'role': 'controller',
    };
    reporter.breadcrumb('playback.ack.waiting', ackContext);
    var done = false;
    AccountOperationScope? scope;
    final baselineSessionId = ref.read(activePlaybackSessionProvider).value?.id;
    final baselineDevices = {
      for (final display in ref.read(displayDevicesProvider).value ?? const [])
        display.id: display,
    };
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
      final current = scope?.isCurrent == true;
      scope?.close();
      if (current &&
          (failure != null || verdict == PlaybackAckVerdict.success)) {
        final devices = {
          for (final display
              in ref.read(displayDevicesProvider).value ?? const [])
            display.id: display,
        };
        for (final targetId in expected.targetDeviceIds) {
          final observed = devices[targetId];
          final display = observed ?? baselineDevices[targetId];
          final received =
              observed?.currentSessionId == expected.id &&
              observed?.acknowledgedRevision == revision;
          recordOperationEvent(
            ref,
            type: received ? 'command_received' : 'command_receipt_failed',
            phase: 'tv_receipt',
            eventId:
                '${expected.id}-$revision-$targetId-${received ? 'received' : 'missing'}',
            sessionId: expected.id,
            workoutId: expected.workout.id,
            workoutName: expected.workout.name,
            deviceId: targetId,
            deviceRole: 'display',
            display: display,
            errorCode: received ? null : 'receipt_timeout',
          );
        }
      }
      reporter.breadcrumb('playback.ack.finished', {
        ...ackContext,
        'status': failure ?? verdict.name,
      });
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
      if (scope?.isCurrent != true) {
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
      if (session?.id == expected.id &&
          session?.status == PlaybackStatus.completed) {
        finish(PlaybackAckVerdict.cancelled);
        return;
      }
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

    scope = AccountOperationScope.capture(
      ref,
      onInvalidated: () => finish(PlaybackAckVerdict.cancelled),
    );
    if (scope == null || scope.ownerId != expected.ownerId) {
      scope?.close();
      attempt.cancel();
      return;
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
      final diagnostic = ref
          .read(errorReporterProvider)
          .capture(
            result.error!,
            result.stackTrace ?? StackTrace.current,
            action: action,
            context: context ?? _context(),
          );
      final captured = context ?? _context();
      recordOperationEvent(
        ref,
        type: 'command_failed',
        phase: 'server_approval',
        eventId: diagnostic.id,
        errorId: diagnostic.id,
        errorCode: result.error is PlaybackFailure
            ? (result.error! as PlaybackFailure).code
            : 'request_failed',
        sessionId: captured['sessionId'] as String?,
        workoutId: captured['workoutId'] as String?,
      );
    }
  }
}

/// Blocks controller commands until a foreground server handshake completes.
/// Every caller joins the same read-only handshake. Cancellation invalidates its
/// result; a later generation waits for it to finish before opening a new one.
@Riverpod(keepAlive: true)
class PlaybackRecoveryController extends _$PlaybackRecoveryController {
  int _epoch = 0;
  int? _flightEpoch;
  Future<void>? _flight;
  String? _incidentId;
  String? _displayIncidentId;
  String? _displayInterruptedSessionId;
  String? _telemetryOwnerId;
  String? _displayConnectionIncidentId;
  PlaybackSession? _disconnectedDisplaySession;

  void _syncTelemetryOwner() {
    try {
      final owner = ref.read(accountOwnerIdProvider).value;
      if (owner == _telemetryOwnerId) return;
      _telemetryOwnerId = owner;
      _incidentId = null;
      _displayIncidentId = null;
      _displayInterruptedSessionId = null;
      _displayConnectionIncidentId = null;
      _disconnectedDisplaySession = null;
    } catch (_) {}
  }

  void recordDisplayConnection({
    required bool connected,
    PlaybackSession? session,
  }) {
    try {
      _syncTelemetryOwner();
      final deviceId = ref.read(deviceIdProvider).value;
      final display = (ref.read(displayDevicesProvider).value ?? const [])
          .where((device) => device.id == deviceId)
          .firstOrNull;
      if (display?.paired != true) {
        _displayConnectionIncidentId = null;
        _disconnectedDisplaySession = null;
        return;
      }
      // Restores an existing outbox even when this mount has no new incident.
      ref.read(operationEventWriterProvider);
      if (!connected &&
          _displayConnectionIncidentId == null &&
          session != null &&
          session.status != PlaybackStatus.completed &&
          !session.briefing &&
          (session.targetDeviceIds.isEmpty
              ? session.zoneId == display!.zoneId
              : session.targetDeviceIds.contains(deviceId))) {
        final incident = _displayConnectionIncidentId = createEventId();
        _disconnectedDisplaySession = session;
        recordOperationEvent(
          ref,
          type: 'connection_failed',
          phase: 'display_connection',
          eventId: incident,
          incidentId: incident,
          sessionId: session.id,
          workoutId: session.workout.id,
          workoutName: session.workout.name,
          deviceId: deviceId,
          deviceRole: 'display',
          display: display,
          playbackImpact: 'none',
          connected: false,
        );
      } else if (connected && _displayConnectionIncidentId != null) {
        final previous = _disconnectedDisplaySession;
        recordOperationEvent(
          ref,
          type: 'connection_recovered',
          phase: 'display_connection',
          incidentId: _displayConnectionIncidentId,
          recoveryOfEventId: _displayConnectionIncidentId,
          sessionId: previous?.id,
          workoutId: previous?.workout.id,
          workoutName: previous?.workout.name,
          deviceId: deviceId,
          deviceRole: 'display',
          display: display,
          playbackImpact: 'none',
          connected: true,
        );
        _displayConnectionIncidentId = null;
        _disconnectedDisplaySession = null;
      }
    } catch (_) {
      // Local timing must not depend on telemetry/storage availability.
    }
  }

  void recordDisplayCompletion(PlaybackSession session) {
    try {
      final deviceId = ref.read(deviceIdProvider).value;
      final display = (ref.read(displayDevicesProvider).value ?? const [])
          .where((device) => device.id == deviceId)
          .firstOrNull;
      if (display?.paired != true) return;
      recordOperationEvent(
        ref,
        type: 'display_playback_completed',
        phase: 'local_completion',
        sessionId: session.id,
        workoutId: session.workout.id,
        workoutName: session.workout.name,
        deviceId: deviceId,
        deviceRole: 'display',
        display: display,
        connected: ref.read(playbackConnectionProvider).value == true,
        playbackImpact: 'none',
      );
    } catch (_) {}
  }

  void recordDisplayVisibility({required bool visible, bool shutdown = false}) {
    try {
      _syncTelemetryOwner();
      final session = ref.read(activePlaybackSessionProvider).value;
      if (_displayInterruptedSessionId != null &&
          session?.id != _displayInterruptedSessionId) {
        // The old class remains without recovery evidence; release the local
        // tracker so a later class can independently record an interruption.
        _displayIncidentId = null;
        _displayInterruptedSessionId = null;
      }
      final localDeviceId = ref.read(deviceIdProvider).value;
      final displays = ref.read(displayDevicesProvider).value ?? const [];
      final matching = displays.where((device) => device.id == localDeviceId);
      final display = matching.isEmpty ? null : matching.first;
      if (shutdown) {
        recordOperationEvent(
          ref,
          type: 'device_shutdown',
          phase: 'app_lifecycle',
          sessionId: session?.id,
          deviceId: localDeviceId,
          display: display,
        );
      } else if (!visible &&
          _displayIncidentId == null &&
          session?.status == PlaybackStatus.playing &&
          session?.briefing == false &&
          session!.targetDeviceIds.contains(localDeviceId)) {
        _displayIncidentId = createEventId();
        _displayInterruptedSessionId = session.id;
        recordOperationEvent(
          ref,
          type: 'playback_interrupted',
          phase: 'app_lifecycle',
          eventId: _displayIncidentId,
          incidentId: _displayIncidentId,
          sessionId: session.id,
          workoutId: session.workout.id,
          workoutName: session.workout.name,
          deviceId: localDeviceId,
          display: display,
          playbackImpact: 'interrupted',
        );
      } else if (visible &&
          _displayIncidentId != null &&
          session?.id == _displayInterruptedSessionId &&
          session?.status == PlaybackStatus.playing) {
        recordOperationEvent(
          ref,
          type: 'playback_restored',
          phase: 'app_lifecycle',
          workoutId: session?.workout.id,
          workoutName: session?.workout.name,
          incidentId: _displayIncidentId,
          recoveryOfEventId: _displayIncidentId,
          sessionId: session?.id,
          deviceId: localDeviceId,
          display: display,
        );
        _displayIncidentId = null;
        _displayInterruptedSessionId = null;
      }
    } catch (_) {
      // Visibility changes must remain independent of diagnostic availability.
    }
  }

  @override
  AsyncValue<void> build() {
    ref.onDispose(() => ++_epoch);
    return const AsyncData(null);
  }

  void suspend() {
    ++_epoch;
    state = const AsyncLoading();
  }

  Future<bool> recoverConfirmed({bool restartTransport = false}) async {
    final epoch = _epoch;
    await recover(restartTransport: restartTransport);
    return ref.mounted &&
        epoch == _epoch &&
        !state.isLoading &&
        !state.hasError &&
        state.hasValue;
  }

  Future<void> recover({bool restartTransport = true}) {
    _syncTelemetryOwner();
    final pending = _flight;
    if (pending != null) {
      if (_flightEpoch == _epoch) return pending;
      final epoch = _epoch;
      return pending.then<void>((_) async {
        if (!ref.mounted || epoch != _epoch) return;
        await recover(restartTransport: restartTransport);
      });
    }
    final epoch = _epoch;
    _flightEpoch = epoch;
    final task = _recover(epoch, restartTransport: restartTransport);
    return _flight = task.whenComplete(() {
      _flight = null;
      _flightEpoch = null;
    });
  }

  Future<void> _recover(int epoch, {required bool restartTransport}) async {
    final elapsed = Stopwatch()..start();
    state = const AsyncLoading();
    void Function()? closeActions;
    try {
      closeActions = ref.listen(playbackActionsProvider, (old, next) {
        if (!identical(old, next)) suspend();
      }).close;
      final actions = ref.read(playbackActionsProvider);
      await actions.recover(restartTransport: restartTransport);
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
        // Invalidation retains the previous error/value while a fresh stream
        // loads. It must not decide this handshake before the new result.
        if (received.isCompleted || next.isLoading) return;
        if (next.hasError) {
          received.completeError(next.error!, next.stackTrace);
        } else {
          received.complete();
        }
      }, fireImmediately: true);
      try {
        await received.future.timeout(const Duration(seconds: 6));
      } finally {
        subscription.close();
      }
      if (ref.mounted && epoch == _epoch) {
        state = const AsyncData(null);
        final incident = _incidentId;
        if (incident != null) {
          recordOperationEvent(
            ref,
            type: 'connection_recovered',
            phase: 'controller_connection',
            incidentId: incident,
            recoveryOfEventId: incident,
            sessionId: ref.read(activePlaybackSessionProvider).value?.id,
          );
          _incidentId = null;
        }
      }
    } catch (error, stack) {
      if (ref.mounted && epoch == _epoch) {
        state = AsyncError(error, stack);
        final diagnostic = ref
            .read(errorReporterProvider)
            .capture(
              error,
              stack,
              action: 'playback.recover',
              context: {'elapsedMs': elapsed.elapsedMilliseconds},
            );
        final firstFailure =
            _incidentId == null && _displayConnectionIncidentId == null;
        if (_displayConnectionIncidentId == null) {
          _incidentId ??= createEventId();
        }
        if (firstFailure) {
          recordOperationEvent(
            ref,
            type: 'connection_failed',
            phase: 'controller_connection',
            eventId: _incidentId,
            incidentId: _incidentId,
            errorId: diagnostic.id,
            errorCode: 'recovery_failed',
            sessionId: ref.read(activePlaybackSessionProvider).value?.id,
          );
        }
      }
    } finally {
      closeActions?.call();
    }
  }
}
