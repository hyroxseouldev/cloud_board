import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/services/event_id.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_recovery.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/display_recovery_actions.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'display_recovery_controller.g.dart';

@riverpod
class DisplayRecoveryController extends _$DisplayRecoveryController {
  int _epoch = 0;
  bool _requesting = false;
  StreamSubscription<DisplayRecoveryRequest?>? _subscription;
  Timer? _timer;
  Timer? _initialDeadline;
  @override
  AsyncValue<DisplayRecoveryRequest?> build(String deviceId) {
    final epoch = ++_epoch;
    _requesting = false;
    final owner = ref.watch(accountOwnerIdProvider);
    if (owner.isLoading || owner.hasError || owner.value == null) {
      return const AsyncData(null);
    }
    // Keep the clock stream subscribed; a read-only provider can be paused in
    // Riverpod 3 and would leave expiration on an unadjusted local clock.
    ref.listen(serverTimeOffsetProvider, (_, _) {});
    final actions = ref.watch(displayRecoveryActionsProvider);
    _initialDeadline = Timer(const Duration(seconds: 10), () {
      if (ref.mounted && epoch == _epoch && state.isLoading && !_requesting) {
        state = AsyncError(
          TimeoutException('TV 복구 상태를 불러오지 못했습니다.'),
          StackTrace.current,
        );
      }
    });
    _subscription = actions
        .watch(deviceId)
        .listen(
          (value) {
            _initialDeadline?.cancel();
            if (!ref.mounted ||
                epoch != _epoch ||
                (_requesting && value == null)) {
              return;
            }
            _accept(value);
          },
          onError: (Object error, StackTrace stack) {
            _initialDeadline?.cancel();
            if (ref.mounted && epoch == _epoch) {
              state = AsyncError(error, stack);
            }
          },
        );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!ref.mounted || epoch != _epoch) return;
      final current = state.value;
      if (current != null && current.pending && current.expired(_now())) {
        state = AsyncData(current.expire());
      }
    });
    ref.onDispose(() {
      _epoch++;
      _timer?.cancel();
      _initialDeadline?.cancel();
      unawaited(_subscription?.cancel());
    });
    ref.listen(displayDevicesProvider, (_, next) {
      if (next.isLoading || next.hasError || !next.hasValue) return;
      final current = state.value;
      if (current != null &&
          current.pending &&
          !next.value!.any(
            (device) => device.id == deviceId && device.paired,
          )) {
        state = AsyncData(
          DisplayRecoveryRequest(
            operationId: current.operationId,
            deviceId: current.deviceId,
            status: DisplayRecoveryStatus.failed,
            requestedAtMs: current.requestedAtMs,
            expiresAtMs: current.expiresAtMs,
            errorCode: 'device_unpaired',
          ),
        );
      }
    });
    return const AsyncLoading();
  }

  int _now() =>
      DateTime.now().millisecondsSinceEpoch +
      (ref.read(serverTimeOffsetProvider).value ?? 0);
  void _accept(DisplayRecoveryRequest? value) {
    final current = state.value;
    if (current != null &&
        value != null &&
        current.operationId != value.operationId &&
        current.requestedAtMs > value.requestedAtMs) {
      return;
    }
    if (value != null &&
        current != null &&
        current.operationId == value.operationId &&
        (current.terminal || current.status.index > value.status.index)) {
      return;
    }
    state = AsyncData(
      value != null && value.pending && value.expired(_now())
          ? value.expire()
          : value,
    );
  }

  Future<bool> request() async {
    final owner = ref.read(accountOwnerIdProvider);
    if (_requesting ||
        state.value?.pending == true ||
        owner.isLoading ||
        owner.hasError ||
        owner.value == null) {
      return false;
    }
    final epoch = _epoch;
    final ownerId = owner.value;
    _requesting = true;
    state = const AsyncLoading();
    String? operationId;
    // ID generation and provider/repository access can throw synchronously.
    // Include them in the guarded flight so every failure releases Loading.
    final flight =
        Future<DisplayRecoveryRequest>.sync(() {
          operationId = 'recovery-${createEventId()}';
          return ref
              .read(displayRecoveryActionsProvider)
              .request(deviceId, operationId!);
        }).whenComplete(() {
          if (ref.mounted && epoch == _epoch) _requesting = false;
        });
    final result = await AsyncValue.guard(
      () => flight.timeout(const Duration(seconds: 16)),
    );
    if (!ref.mounted ||
        epoch != _epoch ||
        ref.read(accountOwnerIdProvider).value != ownerId) {
      return false;
    }
    if (result.hasError) {
      // A snapshot acknowledgement may arrive before the callable response.
      // Preserve it when the response is lost or delayed.
      if (operationId != null && state.value?.operationId == operationId) {
        return true;
      }
      state = AsyncError(result.error!, result.stackTrace!);
      return false;
    }
    _accept(result.value);
    return true;
  }
}

/// Authorization failures require a real identity/connection transition. Only
/// transient transport failures receive three bounded retries (1, 2, 4 seconds).
Duration? displayRecoveryRetry(int attempt, Object error) {
  if (attempt >= 3) return null;
  final transient =
      error is TimeoutException ||
      (error is FirebaseException &&
          const {
            'unavailable',
            'network-error',
            'network-request-failed',
            'disconnected',
            'deadline-exceeded',
            'connection-timeout',
          }.contains(error.code));
  return transient ? Duration(seconds: 1 << attempt) : null;
}

/// A visible browser display remains available when another window has input
/// focus. Hidden browser tabs and background native/TV apps still stop work.
bool displayRecoveryAllowedInLifecycle(
  AppLifecycleState? state, {
  bool isWeb = kIsWeb,
}) =>
    state == null ||
    state == AppLifecycleState.resumed ||
    (isWeb && state == AppLifecycleState.inactive);

bool get displayRecoveryInForeground =>
    displayRecoveryAllowedInLifecycle(WidgetsBinding.instance.lifecycleState);

@Riverpod(retry: displayRecoveryRetry)
Stream<DisplayRecoveryRequest?> displayRecoveryRequest(
  Ref ref,
  String deviceId,
) {
  final owner = ref.watch(accountOwnerIdProvider);
  if (!displayRecoveryInForeground ||
      owner.isLoading ||
      owner.hasError ||
      owner.value == null) {
    return Stream.value(null);
  }
  return ref.watch(displayRecoveryActionsProvider).watch(deviceId);
}
