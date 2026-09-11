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
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_briefing_board.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

class WorkoutPlayerScreen extends ConsumerWidget {
  const WorkoutPlayerScreen({
    super.key,
    required this.workoutId,
    required this.startModule,
    this.sessionId,
    this.displayMode = false,
    this.onStandby,
  });
  final String workoutId;
  final int startModule;
  final String? sessionId;
  final bool displayMode;
  final VoidCallback? onStandby;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteSession = sessionId == null
        ? null
        : ref.watch(activePlaybackSessionProvider).value;
    if (sessionId != null && remoteSession?.id != sessionId) {
      return const Scaffold(body: Center(child: Text('수업 화면을 준비하고 있습니다…')));
    }
    final matchesSession = sessionId != null && remoteSession?.id == sessionId;
    final workouts = matchesSession
        ? const <Workout>[]
        : ref.watch(workoutControllerProvider).value ?? const <Workout>[];
    final workout = matchesSession
        ? remoteSession!.workout
        : workouts.where((item) => item.id == workoutId).firstOrNull;
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
  });

  final Workout workout;
  final int startModule;
  final String? sessionId;
  final bool displayMode;
  final VoidCallback? onStandby;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = playerControllerProvider(
      workout,
      startModule: startModule,
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
    final showControls = useState(!displayMode);
    final standbyNow = useState(DateTime.now());
    useEffect(() {
      if (!displayMode || !state.briefing) return null;
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => standbyNow.value = DateTime.now(),
      );
      return timer.cancel;
    }, [displayMode, state.briefing]);

    Future<void> exitPlayer() async {
      if (sessionId != null && !displayMode) {
        final success = await ref
            .read(playbackActionControllerProvider.notifier)
            .complete();
        if (!success || !context.mounted) return;
      }
      if (context.mounted) context.go('/');
    }

    Future<void> requestExit() async {
      if (displayMode) return;
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
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return () {
        unawaited(WakelockPlus.disable());
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      };
    }, [displayMode, isTv]);

    useEffect(() {
      if (displayMode) return null;
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
    useEffect(() {
      if (hasCurrentStep || !displayMode || onStandby == null) return null;
      final timer = Timer(const Duration(seconds: 5), onStandby!);
      return timer.cancel;
    }, [hasCurrentStep, displayMode]);
    useEffect(
      () {
        if (displayMode) return null;
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
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(requestExit());
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
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(requestExit());
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '준비하세요',
                  style: TextStyle(color: Colors.white70, fontSize: 28),
                ),
                Text(
                  '${(state.countdownMs / 1000).ceil()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 160,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  currentMediaStep?.module.name ?? workout.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (state.steps.isEmpty || state.index >= state.steps.length) {
      return _DoneScreen(workout: workout, displayMode: displayMode);
    }

    final step = state.steps[state.index];
    final module = step.module;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(requestExit());
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
            onTap: displayMode
                ? null
                : () => showControls.value = !showControls.value,
            child: AsyncActionOverlay(
              isLoading: playbackAction.isLoading,
              child: Scaffold(
                backgroundColor: Colors.black,
                body: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final scale = constraints.maxWidth / 1280;
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: WorkoutSlideCanvas(
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
                              if (showControls.value && !displayMode)
                                _Controls(
                                  onPrevious: () => actions.previous(),
                                  onToggle: () => actions.toggle(),
                                  onNext: () => actions.next(),
                                  paused: state.isPaused,
                                  indexLabel:
                                      '${step.moduleIndex + 1} / ${workout.modules.length}',
                                  onExit: () => unawaited(requestExit()),
                                  scale: scale,
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

class _Controls extends StatelessWidget {
  const _Controls({
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.paused,
    required this.indexLabel,
    required this.onExit,
    required this.scale,
  });
  final VoidCallback onPrevious, onToggle, onNext, onExit;
  final bool paused;
  final String indexLabel;
  final double scale;
  @override
  Widget build(BuildContext context) => Positioned(
    left: 24 * scale,
    right: 24 * scale,
    bottom: 28 * scale,
    child: SafeArea(
      top: false,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12 * scale),
            border: Border.all(color: Colors.white38),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 8 * scale,
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10 * scale,
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.skip_previous, color: Colors.white),
                ),
                FilledButton.icon(
                  onPressed: onToggle,
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                  label: Text(paused ? '재생' : '일시정지'),
                  style: FilledButton.styleFrom(
                    textStyle: TextStyle(fontSize: 16 * scale),
                    padding: EdgeInsets.symmetric(
                      horizontal: 18 * scale,
                      vertical: 14 * scale,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                ),
                Text(
                  indexLabel,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                OutlinedButton(
                  onPressed: onExit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('종료'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DoneScreen extends StatelessWidget {
  const _DoneScreen({required this.workout, required this.displayMode});
  final Workout workout;
  final bool displayMode;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'WORKOUT DONE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${workout.name} · ${durationLabel(workoutDuration(workout))}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 22),
          if (displayMode)
            const Text(
              '잠시 후 대기 화면으로 돌아갑니다',
              style: TextStyle(color: Colors.white70),
            ),
          if (!displayMode)
            OutlinedButton(
              onPressed: () => context.go('/'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('닫기'),
            ),
        ],
      ),
    ),
  );
}
