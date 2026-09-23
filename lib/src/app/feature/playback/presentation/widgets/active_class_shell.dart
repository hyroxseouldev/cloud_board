import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/widgets/web_page_frame.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

/// Session lifetime belongs to the signed-in shell, not the full player route.
/// The navigator is above the bar so page FABs and save actions get real space.
class ActiveClassShell extends HookConsumerWidget {
  const ActiveClassShell({
    super.key,
    required this.child,
    required this.playerVisible,
    this.homeVisible = false,
  });
  final Widget child;
  final bool playerVisible;
  final bool homeVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(deviceModeControllerProvider).value;
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
    return WebPageFrame(
      fullWidth: playerVisible || (homeVisible && mode == DeviceMode.display),
      child: Stack(
        fit: StackFit.expand,
        children: [
          showActiveClass
              ? _ActiveClass(
                  key: ValueKey(session.id),
                  session: session,
                  playerVisible: playerVisible,
                  child: child,
                )
              : child,
          if (mode == DeviceMode.controller &&
              !recovery.hasValue &&
              playerVisible)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (recovery.isLoading)
                            const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            recovery.hasError
                                ? '수업 상태를 확인하지 못했습니다. 네트워크를 확인해 주세요.'
                                : '최신 수업 상태를 확인하고 있습니다…',
                            textAlign: TextAlign.center,
                          ),
                          if (recovery.hasError)
                            TextButton(
                              onPressed: () => unawaited(
                                ref
                                    .read(
                                      playbackRecoveryControllerProvider
                                          .notifier,
                                    )
                                    .recover(),
                              ),
                              child: const Text('다시 연결'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveClass extends HookConsumerWidget {
  const _ActiveClass({
    super.key,
    required this.session,
    required this.child,
    required this.playerVisible,
  });
  final PlaybackSession session;
  final Widget child;
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
    final connected =
        ref.watch(playbackConnectionProvider).value == true &&
        ref.watch(playbackRecoveryControllerProvider).hasValue;
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
    if (hidden) return child;
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
    return Column(
      children: [
        Expanded(
          // The mini controller below already owns the bottom safe area.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: child,
          ),
        ),
        Material(
          color: AppColors.surface,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 76,
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('expand-class'),
                      onTap: () => context.push(
                        Uri(
                          path: '/player/${session.workout.id}',
                          queryParameters: {'session': session.id},
                        ).toString(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 64,
                                height: 44,
                                child: step.module.imageSource.isEmpty
                                    ? const ColoredBox(
                                        color: AppColors.selected,
                                        child: Icon(Icons.slideshow_outlined),
                                      )
                                    : WorkoutImage(
                                        source: step.module.imageSource,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.workout.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (ref.watch(playbackRecoveryControllerProvider).hasError)
                    IconButton(
                      tooltip: '다시 연결',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => unawaited(
                        ref
                            .read(playbackRecoveryControllerProvider.notifier)
                            .recover(),
                      ),
                    ),
                  IconButton(
                    tooltip: '이전 슬라이드',
                    onPressed: disabled || step.moduleIndex == 0
                        ? null
                        : () => unawaited(
                            actions.selectModule(step.moduleIndex - 1),
                          ),
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  IconButton(
                    tooltip: state.isPaused ? '수업 재개' : '수업 일시정지',
                    onPressed: disabled
                        ? null
                        : () => unawaited(actions.toggle()),
                    icon: Icon(
                      state.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 슬라이드',
                    onPressed:
                        disabled ||
                            step.moduleIndex + 1 >=
                                session.workout.modules.length
                        ? null
                        : () => unawaited(
                            actions.selectModule(step.moduleIndex + 1),
                          ),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
