import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/workout.dart';
import '../controllers/player_controller.dart';
import '../controllers/workout_controller.dart';
import 'workout_list_screen.dart';

class WorkoutPlayerScreen extends HookConsumerWidget {
  const WorkoutPlayerScreen({
    super.key,
    required this.workoutId,
    required this.startModule,
  });
  final String workoutId;
  final int startModule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts =
        ref.watch(workoutControllerProvider).value ?? const <Workout>[];
    final workout = workouts.where((item) => item.id == workoutId).firstOrNull;
    if (workout == null) {
      return const Scaffold(body: Center(child: Text('워크아웃을 찾을 수 없습니다.')));
    }
    final state = ref.watch(
      playerControllerProvider(workout, startModule: startModule),
    );
    final actions = ref.read(
      playerControllerProvider(workout, startModule: startModule).notifier,
    );
    final showControls = useState(true);
    useEffect(() {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }, const []);
    if (state.steps.isEmpty || state.index >= state.steps.length) {
      return _DoneScreen(workout: workout);
    }

    final step = state.steps[state.index];
    final module = step.module;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): actions.toggle,
        const SingleActivator(LogicalKeyboardKey.arrowRight): actions.next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): actions.previous,
        const SingleActivator(LogicalKeyboardKey.escape): () => context.pop(),
      },
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          onTap: () => showControls.value = !showControls.value,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                if (module.imageSource.isNotEmpty)
                  Positioned.fill(
                    child: module.imageSource.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: module.imageSource,
                            fit: module.coverImage
                                ? BoxFit.cover
                                : BoxFit.contain,
                          )
                        : Image.memory(
                            base64Decode(module.imageSource),
                            fit: module.coverImage
                                ? BoxFit.cover
                                : BoxFit.contain,
                          ),
                  ),
                Positioned.fill(
                  child: ColoredBox(
                    color: module.imageSource.isEmpty
                        ? Colors.black
                        : Colors.black.withValues(alpha: .28),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: (1 - state.secondsLeft / step.duration).clamp(0, 1),
                    minHeight: 7,
                    backgroundColor: Colors.white24,
                    color: XonColors.cobalt,
                  ),
                ),
                SafeArea(
                  child: _PlayerContent(
                    workout: workout,
                    step: step,
                    state: state,
                  ),
                ),
                if (state.isPaused)
                  const Positioned(
                    top: 48,
                    right: 28,
                    child: Chip(
                      label: Text(
                        '일시정지',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      backgroundColor: Colors.black87,
                    ),
                  ),
                if (showControls.value)
                  _Controls(
                    onPrevious: actions.previous,
                    onToggle: actions.toggle,
                    onNext: actions.next,
                    paused: state.isPaused,
                    indexLabel:
                        '${step.moduleIndex + 1} / ${workout.modules.length}',
                    onExit: () => context.pop(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerContent extends StatelessWidget {
  const _PlayerContent({
    required this.workout,
    required this.step,
    required this.state,
  });
  final Workout workout;
  final PlayerStep step;
  final PlayerState state;
  @override
  Widget build(BuildContext context) {
    final isRest = step.isRest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isRest ? '휴식' : step.module.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 12)],
                  ),
                ),
              ),
              if (step.totalSets > 1)
                Text(
                  '${step.set} / ${step.totalSets} 세트',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
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
                child: Text(
                  isRest ? '다음: ${step.set + 1}세트' : step.module.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    shadows: [Shadow(blurRadius: 12)],
                  ),
                ),
              ),
              if (isRest || step.module.showTimer)
                Text(
                  durationLabel(state.secondsLeft),
                  style: TextStyle(
                    color: isRest
                        ? XonColors.cobalt
                        : state.secondsLeft <= 3
                        ? const Color(0xFFFF3B30)
                        : Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -4,
                    shadows: const [Shadow(blurRadius: 24)],
                  ),
                ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                workout.brandL,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                workout.brandR,
                style: const TextStyle(
                  color: Colors.white70,
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

class _Controls extends StatelessWidget {
  const _Controls({
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.paused,
    required this.indexLabel,
    required this.onExit,
  });
  final VoidCallback onPrevious, onToggle, onNext, onExit;
  final bool paused;
  final String indexLabel;
  @override
  Widget build(BuildContext context) => Positioned(
    left: 20,
    right: 20,
    bottom: 32,
    child: SafeArea(
      top: false,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white38),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.skip_previous, color: Colors.white),
                ),
                FilledButton.icon(
                  onPressed: onToggle,
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                  label: Text(paused ? '재생' : '일시정지'),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                ),
                Text(
                  indexLabel,
                  style: const TextStyle(
                    color: Colors.white70,
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
  const _DoneScreen({required this.workout});
  final Workout workout;
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
          OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('닫기'),
          ),
        ],
      ),
    ),
  );
}
