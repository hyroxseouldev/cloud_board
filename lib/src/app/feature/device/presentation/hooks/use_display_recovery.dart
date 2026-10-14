import 'dart:async';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/display_recovery_actions.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/execute_display_recovery.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_recovery_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void useDisplayRecovery(
  BuildContext context,
  WidgetRef ref, {
  required String? deviceId,
  required bool paired,
  required bool connected,
}) {
  final lifecycle = useAppLifecycleState();
  final foreground =
      lifecycle == null || lifecycle == AppLifecycleState.resumed;
  final owner = ref.watch(accountOwnerIdProvider);
  final enabled =
      paired &&
      deviceId != null &&
      !owner.isLoading &&
      !owner.hasError &&
      owner.value != null;
  // Dropping the subscription while backgrounded/disconnected disposes its
  // retry timer; a later foreground/connection resumes with a fresh scope.
  final listening = enabled && connected && foreground;
  // A paused app may not render a frame. Observe the lifecycle directly so a
  // quick background/resume still cancels retry timers and refreshes a denied
  // stream, even when useAppLifecycleState rebuilds only once after resume.
  useOnAppLifecycleStateChange((previous, current) {
    if (previous == current || !enabled || !context.mounted) {
      return;
    }
    final currentOwner = ref.read(accountOwnerIdProvider);
    if (currentOwner.isLoading ||
        currentOwner.hasError ||
        currentOwner.value != owner.value) {
      return;
    }
    ref.invalidate(displayRecoveryRequestProvider(deviceId));
  });
  final requestValue = listening
      ? ref.watch(displayRecoveryRequestProvider(deviceId))
      : null;
  final request =
      requestValue == null || requestValue.isLoading || requestValue.hasError
      ? null
      : requestValue.value;
  final actions = listening ? ref.watch(displayRecoveryActionsProvider) : null;
  final wasListening = useRef(false);
  useEffect(() {
    final resumed = listening && !wasListening.value;
    wasListening.value = listening;
    if (!resumed || requestValue?.hasError != true) return null;
    var cancelled = false;
    final ownerAtResume = owner.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!cancelled &&
          context.mounted &&
          ref.read(accountOwnerIdProvider).value == ownerAtResume) {
        ref.invalidate(displayRecoveryRequestProvider(deviceId));
      }
    });
    return () => cancelled = true;
  }, [listening, owner.value, deviceId]);
  useEffect(
    () {
      if (!enabled ||
          !connected ||
          !foreground ||
          request == null ||
          request.terminal) {
        return null;
      }
      var cancelled = false;
      final ownerAtStart = owner.value;
      Future<void> run() => executeDisplayRecovery(
        request: request,
        actions: actions!,
        cancelled: () =>
            cancelled ||
            !displayRecoveryInForeground ||
            !context.mounted ||
            ref.read(accountOwnerIdProvider).isLoading ||
            ref.read(accountOwnerIdProvider).hasError ||
            ref.read(accountOwnerIdProvider).value != ownerAtStart,
        now: () =>
            DateTime.now().millisecondsSinceEpoch +
            (ref.read(serverTimeOffsetProvider).value ?? 0),
        recover: () => ref
            .read(playbackRecoveryControllerProvider.notifier)
            .recoverConfirmed(),
        currentSession: () {
          final value = ref.read(activePlaybackSessionProvider);
          if (value.isLoading || value.hasError || !value.hasValue) {
            throw StateError('수업 상태를 확인하지 못했습니다.');
          }
          return (
            sessionId: value.value?.id,
            revision: value.value?.revision ?? 0,
          );
        },
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!cancelled) unawaited(run());
      });
      return () => cancelled = true;
    },
    [
      enabled,
      connected,
      foreground,
      owner.value,
      deviceId,
      request?.operationId,
      actions,
    ],
  );
}
