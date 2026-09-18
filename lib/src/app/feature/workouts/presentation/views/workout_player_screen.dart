import 'dart:math' as math;

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_countdown.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_viewport.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';
import 'package:cloud_board/src/app/core/services/workout_media_controller.dart';
import 'package:cloud_board/src/app/core/widgets/async_action_overlay.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_control_panel.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_briefing_board.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_preferences_controller.dart';

class WorkoutPlayerScreen extends HookConsumerWidget {
  const WorkoutPlayerScreen({
    super.key,
    required this.workoutId,
    required this.startModule,
    this.sessionId,
    this.displayMode = false,
    this.onStandby,
    this.displayPreferences = const DisplayPreferences(),
  });
  final String workoutId;
  final int startModule;
  final String? sessionId;
  final bool displayMode;
  final VoidCallback? onStandby;
  final DisplayPreferences displayPreferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = sessionId == null
        ? null
        : ref.watch(activePlaybackSessionProvider);
    final remoteSession = remote?.value;
    final seenSession = useRef(false);
    final localSnapshot = useRef<Workout?>(null);
    if (localSnapshot.value?.id != workoutId) localSnapshot.value = null;
    if (remoteSession?.id == sessionId && sessionId != null) {
      seenSession.value = true;
    }
    final ended =
        sessionId != null &&
        seenSession.value &&
        remote?.isLoading == false &&
        remote?.hasError == false &&
        remoteSession?.id != sessionId;
    useEffect(() {
      if (!ended) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        if (displayMode) {
          onStandby?.call();
        } else {
          await ref.read(workoutMediaControllerProvider).hide();
          if (!context.mounted) return;
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        }
      });
      return null;
    }, [ended]);
    if (sessionId != null && remoteSession?.id != sessionId) {
      return Scaffold(
        body: Center(
          child: Text(
            remote?.hasError == true ? '수업 연결을 확인해 주세요.' : '수업 화면을 준비하고 있습니다…',
          ),
        ),
      );
    }
    final matchesSession = sessionId != null && remoteSession?.id == sessionId;
    final detail = matchesSession
        ? null
        : ref.watch(localPlaybackWorkoutProvider(workoutId));
    if (localSnapshot.value == null && detail?.isLoading == true) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (localSnapshot.value == null && detail?.hasError == true) {
      return Scaffold(
        body: Center(child: Text('운동을 불러오지 못했습니다: ${detail!.error}')),
      );
    }
    if (!matchesSession &&
        localSnapshot.value == null &&
        detail?.value != null) {
      localSnapshot.value = detail!.value;
    }
    final workout = matchesSession
        ? remoteSession!.workout
        : localSnapshot.value;
    if (workout == null) {
      return const Scaffold(body: Center(child: Text('워크아웃을 찾을 수 없습니다.')));
    }
    return _WorkoutPlayerBody(
      key: ValueKey(sessionId ?? workout.id),
      workout: workout,
      startModule: startModule,
      sessionId: sessionId,
      displayMode: displayMode,
      onStandby: onStandby,
      displayPreferences: displayPreferences,
    );
  }
}

class _WorkoutPlayerBody extends HookConsumerWidget {
  const _WorkoutPlayerBody({
    super.key,
    required this.workout,
    required this.startModule,
    required this.sessionId,
    required this.displayMode,
    required this.onStandby,
    required this.displayPreferences,
  });

  final Workout workout;
  final int startModule;
  final String? sessionId;
  final bool displayMode;
  final VoidCallback? onStandby;
  final DisplayPreferences displayPreferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = playerControllerProvider(
      workout,
      startModule: sessionId == null ? startModule : 0,
      sessionId: sessionId,
      canControl: !displayMode,
    );
    // Milliseconds belong to the timer child, not the slide and controls.
    ref.watch(
      provider.select(
        (state) => (
          state.index,
          state.isPaused,
          state.briefing,
          (state.countdownMs / 1000).ceil(),
          state.timelineVersion,
        ),
      ),
    );
    final state = ref.read(provider);
    final actions = ref.read(provider.notifier);
    final playbackAction = ref.watch(playbackActionControllerProvider);
    final isConnected = ref.watch(playbackConnectionProvider).value ?? false;
    final isTv = ref.watch(androidTvProvider).value ?? false;
    final mediaController = ref.watch(workoutMediaControllerProvider);
    final serverOffset = ref.watch(serverTimeOffsetProvider).value ?? 0;
    final standbyNow = useState(DateTime.now());
    final touchLocked = useState(false);
    useEffect(() {
      if (!displayMode || !state.briefing) return null;
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => standbyNow.value = DateTime.now(),
      );
      return timer.cancel;
    }, [displayMode, state.briefing]);

    final exitAllowed = useState(false);
    final exitAttempt = useRef<Future<bool>?>(null);
    Future<bool> performExit() async {
      final active = ref.read(activePlaybackSessionProvider).value;
      if (sessionId != null &&
          !displayMode &&
          active?.id == sessionId &&
          active?.status != PlaybackStatus.completed) {
        final success = await ref
            .read(playbackActionControllerProvider.notifier)
            .complete();
        if (!success || !context.mounted) return false;
      }
      if (context.mounted) {
        await mediaController.hide();
        if (!context.mounted) return false;
        exitAllowed.value = true;
        await WidgetsBinding.instance.endOfFrame;
        if (!context.mounted) return false;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
        return true;
      }
      return false;
    }

    Future<bool> exitPlayer() => exitAttempt.value ??= performExit().then(
      (success) {
        if (!success) exitAttempt.value = null;
        return success;
      },
      onError: (Object error, StackTrace stack) {
        exitAttempt.value = null;
        return false;
      },
    );

    Future<void> minimize() async {
      if (touchLocked.value || displayMode || sessionId == null) return;
      exitAllowed.value = true;
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }

    Future<void> requestExit() async {
      if (displayMode || touchLocked.value) return;
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppAlertDialog(
          title: const Text('수업을 종료할까요?'),
          content: const Text('연결된 디스플레이의 재생도 함께 종료됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('계속 진행'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('수업 종료'),
            ),
          ],
        ),
      );
      if (shouldExit == true && context.mounted) await exitPlayer();
    }

    useEffect(() {
      if (displayMode && isTv) return null;
      unawaited(WakelockPlus.enable());
      SystemChrome.setEnabledSystemUIMode(
        displayMode ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
      return () {
        unawaited(WakelockPlus.disable());
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      };
    }, [displayMode, isTv]);

    useEffect(() {
      if (displayMode || sessionId != null) return null;
      final subscription = mediaController.commands.listen((command) {
        switch (command) {
          case WorkoutMediaCommand.play:
            unawaited(actions.play());
            break;
          case WorkoutMediaCommand.pause:
            unawaited(actions.pause());
            break;
          case WorkoutMediaCommand.next:
            unawaited(actions.next());
            break;
          case WorkoutMediaCommand.previous:
            unawaited(actions.previous());
            break;
          case WorkoutMediaCommand.stop:
            unawaited(exitPlayer());
            break;
        }
      });
      return () {
        unawaited(subscription.cancel());
        unawaited(mediaController.hide());
      };
    }, [displayMode, mediaController, actions]);

    final hasCurrentStep =
        state.steps.isNotEmpty && state.index < state.steps.length;
    final currentMediaStep = hasCurrentStep ? state.steps[state.index] : null;
    final isPreparing = state.briefing || state.countdownMs > 0;
    final imageSize = playbackImageSize(context);
    useEffect(() {
      var cancelled = false;
      final moduleIndex = currentMediaStep?.moduleIndex;
      if (moduleIndex == null) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (cancelled || !context.mounted) return;
        // Keep a small rolling window decoded on both controller and TV.
        unawaited(
          precacheWorkoutImages(
            context,
            workout.modules
                .skip(moduleIndex)
                .take(3)
                .map((module) => module.imageSource),
            isCancelled: () => cancelled,
          ).catchError((Object error) {
            debugPrint('Playback image preparation failed: $error');
            return 0;
          }),
        );
      });
      return () => cancelled = true;
    }, [workout, currentMediaStep?.moduleIndex, imageSize]);
    final exiting = useState(false);
    final exitFailed = useState(false);
    Future<void> finish() async {
      if (exiting.value) return;
      exiting.value = true;
      exitFailed.value = false;
      if (displayMode) {
        onStandby?.call();
        return;
      }
      final success = await exitPlayer();
      if (context.mounted && !success) {
        exiting.value = false;
        exitFailed.value = true;
      }
    }

    useEffect(() {
      if (hasCurrentStep) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) unawaited(finish());
      });
      return null;
    }, [hasCurrentStep]);
    useEffect(
      () {
        if (displayMode || sessionId != null) return null;
        if (currentMediaStep == null || isPreparing) {
          unawaited(mediaController.hide());
          return null;
        }
        unawaited(
          mediaController.show(
            WorkoutMediaSnapshot(
              sessionId: sessionId ?? 'local-${workout.id}',
              workoutName: workout.name,
              slideName: currentMediaStep.module.name.isEmpty
                  ? '슬라이드 ${currentMediaStep.moduleIndex + 1}'
                  : currentMediaStep.module.name,
              statusLabel: currentMediaStep.isRest
                  ? '휴식 · ${currentMediaStep.set}/${currentMediaStep.totalSets}세트'
                  : '운동 · ${currentMediaStep.set}/${currentMediaStep.totalSets}세트',
              durationMs: currentMediaStep.duration * 1000,
              remainingMs: state.remainingMs,
              stepIndex: state.index,
              isPaused: state.isPaused,
            ),
          ),
        );
        return null;
      },
      [
        displayMode,
        mediaController,
        sessionId,
        workout.id,
        workout.name,
        state.index,
        state.isPaused,
        state.timelineVersion,
        isPreparing,
      ],
    );
    if (state.briefing) {
      if (displayMode) {
        return StoreWelcomeBoard(
          brand:
              ref.watch(brandTemplateProvider).value ?? BrandTemplate.initial(),
          now: standbyNow.value,
          connected: isConnected,
        );
      }
      return PopScope(
        canPop: exitAllowed.value,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            unawaited(
              sessionId != null && !displayMode ? minimize() : requestExit(),
            );
          }
        },
        child: WorkoutBriefingBoard(
          workout: workout,
          displayMode: displayMode,
          startModule: currentMediaStep?.moduleIndex ?? 0,
          serverTimeOffsetMs: serverOffset,
          busy: playbackAction.isLoading,
          error: playbackAction.hasError
              ? '시작하지 못했습니다. 연결을 확인하고 다시 눌러 주세요.'
              : null,
          onStart: () => unawaited(
            ref.read(playbackActionControllerProvider.notifier).begin(),
          ),
          onExit: () => unawaited(requestExit()),
        ),
      );
    }
    if (state.countdownMs > 0) {
      return PopScope(
        canPop: exitAllowed.value,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            unawaited(
              sessionId != null && !displayMode ? minimize() : requestExit(),
            );
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: WorkoutCountdown(
            workout: workout,
            seconds: (state.countdownMs / 1000).ceil(),
            slideName: currentMediaStep?.module.name,
            slide: currentMediaStep?.module,
          ),
        ),
      );
    }
    if (state.steps.isEmpty || state.index >= state.steps.length) {
      return Scaffold(
        body: Center(
          child: exitFailed.value
              ? TextButton(
                  onPressed: finish,
                  child: const Text('수업 종료를 전달하지 못했습니다. 다시 시도'),
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    final step = state.steps[state.index];
    final module = step.module;
    if (!displayMode) {
      return PopScope(
        canPop: exitAllowed.value,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            unawaited(
              sessionId != null && !displayMode ? minimize() : requestExit(),
            );
          }
        },
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.space): () {
              if (!touchLocked.value) unawaited(actions.toggle());
            },
            const SingleActivator(LogicalKeyboardKey.arrowRight): () {
              if (!touchLocked.value) unawaited(actions.next());
            },
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
              if (!touchLocked.value) unawaited(actions.previous());
            },
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                unawaited(requestExit()),
          },
          child: Focus(
            autofocus: true,
            child: WorkoutControlPanel(
              title: workout.name,
              moduleCount: workout.modules.length,
              currentModule: step.moduleIndex,
              paused: state.isPaused,
              busy: playbackAction.isLoading,
              locked: touchLocked.value,
              onLockChanged: (value) => touchLocked.value = value,
              onPrevious: () => unawaited(actions.previous()),
              onToggle: () => unawaited(actions.toggle()),
              onNext: () => unawaited(actions.next()),
              onExit: () => unawaited(requestExit()),
              onMinimize: sessionId == null
                  ? null
                  : () => unawaited(minimize()),
              onSelectModule: actions.selectModule,
              message: playbackAction.hasError
                  ? '명령을 전달하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.'
                  : sessionId != null && !isConnected
                  ? '컨트롤러의 서버 연결이 끊겼습니다. 연결 복구 후 수업 상태를 확인해 주세요.'
                  : null,
              timeline: Consumer(
                builder: (context, ref, _) {
                  final live = ref.watch(provider);
                  final durations = List.filled(workout.modules.length, 0);
                  var elapsed = 0;
                  for (var i = 0; i < live.steps.length; i++) {
                    final item = live.steps[i];
                    durations[item.moduleIndex] += item.duration;
                    if (item.moduleIndex == step.moduleIndex) {
                      if (i < live.index) elapsed += item.duration * 1000;
                      if (i == live.index) {
                        elapsed += item.duration * 1000 - live.remainingMs;
                      }
                    }
                  }
                  return WorkoutControlTimeline(
                    durations: durations,
                    currentModule: step.moduleIndex,
                    elapsedMs: elapsed,
                    onSeek:
                        touchLocked.value ||
                            playbackAction.isLoading ||
                            (sessionId != null && !isConnected)
                        ? null
                        : actions.seekModulePosition,
                  );
                },
              ),
              previewBuilder: (context, index) {
                if (index != step.moduleIndex) {
                  return WorkoutSlidePreview(
                    module: workout.modules[index],
                    isRest: false,
                    brandL: workout.brandL,
                    brandR: workout.brandR,
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final scale = math.min(
                      constraints.maxWidth / 1280,
                      constraints.maxHeight / 720,
                    );
                    return WorkoutSlideCanvas(
                      module: module,
                      isRest: step.isRest,
                      secondsLeft: state.secondsLeft,
                      remainingMs: state.remainingMs,
                      durationMs: step.duration * 1000,
                      set: step.set,
                      totalSets: step.totalSets,
                      isPaused: state.isPaused,
                      brandL: workout.brandL,
                      brandR: workout.brandR,
                      scale: scale,
                      showLoadingIndicator: true,
                      timer: _PlayerTimer(
                        workout: workout,
                        startModule: startModule,
                        sessionId: sessionId,
                        displayMode: false,
                        scale: scale,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: exitAllowed.value,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(
            sessionId != null && !displayMode ? minimize() : requestExit(),
          );
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): () =>
              actions.toggle(),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              actions.next(),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              actions.previous(),
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              unawaited(requestExit()),
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            child: AsyncActionOverlay(
              isLoading: playbackAction.isLoading,
              child: Scaffold(
                backgroundColor: Colors.black,
                body: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: DisplayViewport(
                      preferences: displayPreferences,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final scale = math.min(
                            constraints.maxWidth / 1280,
                            constraints.maxHeight / 720,
                          );
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: WorkoutSlideCanvas(
                                  module: module,
                                  displayPreferences: displayPreferences,
                                  isRest: step.isRest,
                                  secondsLeft: state.secondsLeft,
                                  remainingMs: state.remainingMs,
                                  durationMs: step.duration * 1000,
                                  set: step.set,
                                  totalSets: step.totalSets,
                                  isPaused: state.isPaused,
                                  brandL: workout.brandL,
                                  brandR: workout.brandR,
                                  scale: scale,
                                  showLoadingIndicator: true,
                                  timer: _PlayerTimer(
                                    workout: workout,
                                    startModule: startModule,
                                    sessionId: sessionId,
                                    displayMode: displayMode,
                                    scale: scale,
                                  ),
                                ),
                              ),
                              if (state.isPaused)
                                Positioned(
                                  top: 42 * scale,
                                  right: 34 * scale,
                                  child: Chip(
                                    label: Text(
                                      '일시정지',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16 * scale,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    backgroundColor: Colors.black87,
                                  ),
                                ),
                              Positioned(
                                top: 42 * scale,
                                left: 34 * scale,
                                child: _ConnectionChip(
                                  connected: isConnected,
                                  scale: scale,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerTimer extends ConsumerWidget {
  const _PlayerTimer({
    required this.workout,
    required this.startModule,
    required this.sessionId,
    required this.displayMode,
    required this.scale,
  });
  final Workout workout;
  final int startModule;
  final String? sessionId;
  final bool displayMode;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      playerControllerProvider(
        workout,
        startModule: startModule,
        sessionId: sessionId,
        canControl: !displayMode,
      ),
    );
    if (state.index >= state.steps.length) return const SizedBox.shrink();
    final step = state.steps[state.index];
    return WorkoutSlideTimer(
      module: step.module,
      isRest: step.isRest,
      secondsLeft: state.secondsLeft,
      remainingMs: state.remainingMs,
      durationMs: step.duration * 1000,
      isPaused: state.isPaused,
      scale: scale,
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.connected, required this.scale});

  final bool connected;
  final double scale;

  @override
  Widget build(BuildContext context) => connected
      ? const SizedBox.shrink()
      : Chip(
          avatar: Icon(
            Icons.circle,
            size: 10 * scale,
            color: connected ? Colors.greenAccent : Colors.orangeAccent,
          ),
          label: Text(
            '오프라인 · 로컬 재생',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: Colors.black87,
        );
}
