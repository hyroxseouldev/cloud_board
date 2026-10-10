import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_details.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/widgets/web_page_frame.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/widgets/playback_recovery_view.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/widgets/mini_class_bar.dart';

/// Session lifetime belongs to the signed-in shell, not the full player route.
/// The navigator is above the bar so page FABs and save actions get real space.
class ActiveClassShell extends HookConsumerWidget {
  const ActiveClassShell({
    super.key,
    required this.child,
    required this.playerVisible,
    this.homeVisible = false,
    this.navigationBar,
  });
  final Widget child;
  final bool playerVisible;
  final bool homeVisible;
  final Widget? navigationBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(playbackActionControllerProvider, (previous, next) {
      if (next.hasError && next.error != previous?.error) {
        final error = next.error!;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(diagnosticMessage(error)),
            duration: const Duration(seconds: 8),
            action: kDebugMode
                ? SnackBarAction(
                    label: '상세',
                    onPressed: () => showErrorDetails(
                      context,
                      ref.read(errorReporterProvider),
                      error,
                      next.stackTrace,
                      'playback.action',
                    ),
                  )
                : null,
          ),
        );
      }
    });
    final mode = ref.watch(deviceModeControllerProvider).value;
    if (mode == DeviceMode.controller) ref.watch(firstClassControllerProvider);
    final session = ref.watch(activePlaybackSessionProvider).value;
    final recovery = ref.watch(playbackRecoveryControllerProvider);
    final suspended = useRef(false);
    useOnAppLifecycleStateChange((previous, next) {
      if (kIsWeb ||
          defaultTargetPlatform != TargetPlatform.android ||
          mode != DeviceMode.controller) {
        return;
      }
      final notifier = ref.read(playbackRecoveryControllerProvider.notifier);
      if (next == AppLifecycleState.paused &&
          session != null &&
          session.status != PlaybackStatus.completed) {
        suspended.value = true;
        notifier.suspend();
      } else if (next == AppLifecycleState.resumed && suspended.value) {
        suspended.value = false;
        unawaited(notifier.recover());
      }
    });
    final showActiveClass =
        mode == DeviceMode.controller &&
        session != null &&
        session.status != PlaybackStatus.completed &&
        session.workout.modules.isNotEmpty;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final dockVisible =
        mode == DeviceMode.controller &&
        navigationBar != null &&
        !keyboardVisible;
    final miniVisible = showActiveClass && !playerVisible && !keyboardVisible;
    final bottomVisible = dockVisible || miniVisible;
    return WebPageFrame(
      fullWidth: playerVisible || (homeVisible && mode == DeviceMode.display),
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeBottom: bottomVisible,
                    child: child,
                  ),
                ),
                // Keep this subtree (and the session controller) mounted when
                // expanding the player. The route child never moves on session changes.
                Padding(
                  padding: bottomVisible
                      ? const EdgeInsets.fromLTRB(16, 8, 16, 16)
                      : EdgeInsets.zero,
                  child: SafeArea(
                    top: false,
                    bottom: bottomVisible,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showActiveClass)
                          _ActiveClassControls(
                            key: ValueKey(session.id),
                            session: session,
                            playerVisible: playerVisible,
                          ),
                        if (miniVisible && dockVisible)
                          const SizedBox(height: 10),
                        if (dockVisible) navigationBar!,
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (mode == DeviceMode.controller &&
                !recovery.hasValue &&
                playerVisible)
              Positioned.fill(
                child: PlaybackRecoveryView(
                  error: recovery.error,
                  stackTrace: recovery.stackTrace,
                  onRetry: () => unawaited(
                    ref
                        .read(playbackRecoveryControllerProvider.notifier)
                        .recover(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveClassControls extends HookConsumerWidget {
  const _ActiveClassControls({
    super.key,
    required this.session,
    required this.playerVisible,
  });
  final PlaybackSession session;
  final bool playerVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = playerControllerProvider(
      session.workout,
      sessionId: session.id,
    );
    ref.watch(
      provider.select(
        (s) => (
          s.index,
          s.isPaused,
          s.secondsLeft,
          (s.countdownMs / 1000).ceil(),
          s.timelineVersion,
        ),
      ),
    );
    final state = ref.read(provider);
    final actions = ref.read(provider.notifier);
    final recovery = ref.watch(playbackRecoveryControllerProvider);
    final connected =
        ref.watch(playbackConnectionProvider).value == true &&
        recovery.hasValue;
    final command = ref.watch(playbackActionControllerProvider);
    final step = state.index < state.steps.length
        ? state.steps[state.index]
        : null;
    final preparing = state.briefing || state.countdownMs > 0;
    // A recovered class may already have ended while no controller was awake.
    useEffect(() {
      if (step != null ||
          !connected ||
          session.status == PlaybackStatus.completed) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted &&
            ref.read(activePlaybackSessionProvider).value?.id == session.id) {
          unawaited(
            ref.read(playbackActionControllerProvider.notifier).syncComplete(),
          );
        }
      });
      return null;
    }, [step == null, connected, session.revision]);
    final hidden =
        playerVisible ||
        step == null ||
        MediaQuery.viewInsetsOf(context).bottom > 0;
    if (hidden) return const SizedBox.shrink();
    final totalMs = state.steps.fold<int>(
      0,
      (total, item) => total + item.duration * 1000,
    );
    final elapsedMs = preparing
        ? 0
        : state.steps
                  .take(state.index)
                  .fold<int>(0, (total, item) => total + item.duration * 1000) +
              step.duration * 1000 -
              state.remainingMs;
    final progress = totalMs > 0 ? (elapsedMs / totalMs).clamp(0.0, 1.0) : 0.0;
    final disabled = command.isLoading || !connected || preparing;
    final label = !connected
        ? '컨트롤러 서버 연결 확인 중'
        : command.hasError
        ? '명령 전달 실패 · 다시 시도해 주세요'
        : preparing
        ? '수업 시작 준비 중'
        : '${step.module.name.isEmpty ? '슬라이드 ${step.moduleIndex + 1}' : step.module.name} · ${state.isPaused
              ? '일시정지'
              : step.isRest
              ? '휴식'
              : '운동'} · ${state.secondsLeft ~/ 60}:${(state.secondsLeft % 60).toString().padLeft(2, '0')}';
    void expand() => context.push(
      Uri(
        path: '/player/${session.workout.id}',
        queryParameters: {'session': session.id},
      ).toString(),
    );
    return MiniClassBar(
      title: session.workout.name,
      label: label,
      imageSource: step.module.imageSource,
      progress: progress,
      paused: state.isPaused,
      onExpand: expand,
      onToggle: disabled ? null : () => unawaited(actions.toggle()),
      onPrevious: disabled || step.moduleIndex == 0
          ? null
          : () => unawaited(actions.selectModule(step.moduleIndex - 1)),
      onNext: disabled || step.moduleIndex + 1 >= session.workout.modules.length
          ? null
          : () => unawaited(actions.selectModule(step.moduleIndex + 1)),
      onRetry: recovery.hasError
          ? () => unawaited(
              ref.read(playbackRecoveryControllerProvider.notifier).recover(),
            )
          : null,
    );
  }
}
