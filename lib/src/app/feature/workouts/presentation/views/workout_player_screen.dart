import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/services/workout_media_controller.dart';
import 'package:cloud_board/src/app/core/widgets/async_action_overlay.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

class WorkoutPlayerScreen extends HookConsumerWidget {
  const WorkoutPlayerScreen({
    super.key,
    required this.workoutId,
    required this.startModule,
    this.sessionId,
    this.displayMode = false,
  });
  final String workoutId;
  final int startModule;
  final String? sessionId;
  final bool displayMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts =
        ref.watch(workoutControllerProvider).value ?? const <Workout>[];
    final remoteSession = sessionId == null
        ? null
        : ref.watch(activePlaybackSessionProvider).value;
    final workout = remoteSession?.id == sessionId
        ? remoteSession!.workout
        : workouts.where((item) => item.id == workoutId).firstOrNull;
    if (workout == null) {
      return const Scaffold(body: Center(child: Text('워크아웃을 찾을 수 없습니다.')));
    }
    final state = ref.watch(
      playerControllerProvider(
        workout,
        startModule: startModule,
        sessionId: sessionId,
        canControl: !displayMode,
      ),
    );
    final actions = ref.read(
      playerControllerProvider(
        workout,
        startModule: startModule,
        sessionId: sessionId,
        canControl: !displayMode,
      ).notifier,
    );
    final playbackAction = ref.watch(playbackActionControllerProvider);
    final isConnected = ref.watch(playbackConnectionProvider).value ?? false;
    final mediaController = ref.watch(workoutMediaControllerProvider);
    final showControls = useState(!displayMode);

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
        builder: (dialogContext) => AlertDialog(
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
      unawaited(WakelockPlus.enable());
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return () {
        unawaited(WakelockPlus.disable());
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      };
    }, const []);

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
    final isAtStepStart =
        currentMediaStep != null &&
        state.remainingMs >= currentMediaStep.duration * 1000 - 150;
    useEffect(
      () {
        if (displayMode) return null;
        if (currentMediaStep == null) {
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
        isAtStepStart,
      ],
    );
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
                          final scale = (constraints.maxWidth / 1280).clamp(
                            .65,
                            1.5,
                          );
                          return Stack(
                            children: [
                              if (module.imageSource.isNotEmpty)
                                Positioned.fill(
                                  child: WorkoutImage(
                                    source: module.imageSource,
                                    fit: module.coverImage
                                        ? BoxFit.cover
                                        : BoxFit.contain,
                                    showLoadingIndicator: true,
                                  ),
                                ),
                              if (module.imageSource.isEmpty)
                                const Positioned.fill(
                                  child: ColoredBox(color: Colors.black),
                                ),
                              SafeArea(
                                minimum: EdgeInsets.all(20 * scale),
                                child: _PlayerContent(
                                  workout: workout,
                                  step: step,
                                  state: state,
                                  scale: scale,
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

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.connected, required this.scale});

  final bool connected;
  final double scale;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      Icons.circle,
      size: 10 * scale,
      color: connected ? Colors.greenAccent : Colors.orangeAccent,
    ),
    label: Text(
      connected ? '동기화됨' : '오프라인 · 로컬 재생',
      style: TextStyle(
        color: Colors.white,
        fontSize: 13 * scale,
        fontWeight: FontWeight.w700,
      ),
    ),
    backgroundColor: Colors.black87,
  );
}

class _PlayerContent extends StatelessWidget {
  const _PlayerContent({
    required this.workout,
    required this.step,
    required this.state,
    required this.scale,
  });
  final Workout workout;
  final PlayerStep step;
  final PlayerState state;
  final double scale;
  @override
  Widget build(BuildContext context) {
    final isRest = step.isRest;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        28 * scale,
        28 * scale,
        28 * scale,
        20 * scale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isRest ? '휴식' : step.module.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36 * scale,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 12)],
                  ),
                ),
              ),
              if (step.totalSets > 1)
                Text(
                  '${step.set} / ${step.totalSets} 세트',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 22 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  isRest ? '다음: ${step.set + 1}세트' : step.module.text,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40 * scale,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    shadows: [Shadow(blurRadius: 12)],
                  ),
                ),
              ),
              if (isRest || step.module.showTimer)
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _CircularTimer(
                      secondsLeft: state.secondsLeft,
                      remainingMs: state.remainingMs,
                      durationMs: step.duration * 1000,
                      isRest: isRest,
                      isPaused: state.isPaused,
                      timerColorValue: step.module.timerColorValue,
                      scale: scale,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                workout.brandL,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                workout.brandR,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircularTimer extends StatelessWidget {
  const _CircularTimer({
    required this.secondsLeft,
    required this.remainingMs,
    required this.durationMs,
    required this.isRest,
    required this.isPaused,
    required this.timerColorValue,
    required this.scale,
  });

  final int secondsLeft;
  final int remainingMs;
  final int durationMs;
  final bool isRest, isPaused;
  final int? timerColorValue;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final selectedColor = timerColorValue == null
        ? null
        : Color(timerColorValue!);
    final color = secondsLeft <= 3
        ? const Color(0xFFFF3B30)
        : selectedColor ?? (isRest ? XonColors.cobalt : Colors.white);
    final progress = durationMs <= 0
        ? 0.0
        : (remainingMs / durationMs).clamp(0.0, 1.0);
    final diameter = 260 * scale;
    return Semantics(
      label: '남은 시간 ${durationLabel(secondsLeft)}',
      child: SizedBox.square(
        dimension: diameter,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: isPaused
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              curve: Curves.linear,
              builder: (context, animatedProgress, child) =>
                  CircularProgressIndicator(
                    value: animatedProgress,
                    strokeWidth: 18 * scale,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white24,
                    color: color,
                  ),
            ),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.all(28 * scale),
                  child: Text(
                    durationLabel(secondsLeft),
                    style: TextStyle(
                      color: color,
                      fontSize: 64 * scale,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3 * scale,
                      shadows: const [Shadow(blurRadius: 20)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
