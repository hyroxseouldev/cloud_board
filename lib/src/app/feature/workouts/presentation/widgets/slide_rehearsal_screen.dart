import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_rehearsal.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_rehearsal_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';

class SlideRehearsalScreen extends HookConsumerWidget {
  const SlideRehearsalScreen({
    super.key,
    required this.module,
    required this.brandL,
    required this.brandR,
    this.workout,
  });
  final WorkoutModule module;
  final String brandL, brandR;
  final Workout? workout;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = slideRehearsalControllerProvider(module);
    final state = ref.watch(provider);
    final actions = ref.read(provider.notifier);
    final frame = rehearsalFrame(module, state.positionMs);
    final total = workoutModuleDuration(module) * 1000;
    final player = useRef<BeepPlayer?>(null);
    final soundError = useState<String?>(null);
    useEffect(
      () => () {
        unawaited(player.value?.dispose());
      },
      [],
    );
    useOnAppLifecycleStateChange((previous, next) {
      if (next != AppLifecycleState.resumed) actions.pause();
    });
    Future<void> sound(WorkoutSound value) async {
      try {
        player.value ??= BeepPlayer();
        await player.value!.play(value, workout?.soundVolume ?? 1);
      } catch (_) {
        if (context.mounted) soundError.value = '이 기기에서 소리를 재생하지 못했습니다.';
      }
    }

    ref.listen(provider, (previous, next) {
      if (previous == null || !previous.playing || !module.beep) return;
      final before = rehearsalFrame(module, previous.positionMs);
      final after = rehearsalFrame(module, next.positionMs);
      if (next.positionMs >= total) {
        unawaited(sound(workout?.workoutEndSound ?? WorkoutSound.longFinish));
      } else if (before.startMs != after.startMs) {
        unawaited(
          sound(
            after.isRest
                ? (workout?.restStartSound ?? WorkoutSound.lowPulse)
                : (workout?.workStartSound ?? WorkoutSound.sharpBeep),
          ),
        );
      } else if (before.secondsLeft != after.secondsLeft &&
          after.secondsLeft <= 3 &&
          next.playing) {
        unawaited(sound(workout?.countdownSound ?? WorkoutSound.classicBeep));
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('슬라이드 시험 재생')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('이 기기에서만 재생됩니다. 실제 수업에는 반영되지 않습니다.'),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: LayoutBuilder(
                    builder: (context, constraints) => WorkoutSlideCanvas(
                      module: module,
                      isRest: frame.isRest,
                      secondsLeft: frame.secondsLeft,
                      remainingMs: frame.remainingMs,
                      durationMs: frame.durationMs,
                      set: frame.set,
                      totalSets: frame.totalSets,
                      isPaused: !state.playing,
                      brandL: brandL,
                      brandR: brandR,
                      scale: constraints.maxWidth / 1280,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '블록 ${frame.blockIndex + 1} · ${frame.set}/${frame.totalSets}세트 · ${frame.isRest ? '휴식' : '운동'} · ${durationLabel(state.positionMs ~/ 1000)} / ${durationLabel(total ~/ 1000)}',
                  ),
                  Slider(
                    key: const ValueKey('rehearsal-seek'),
                    label: durationLabel(state.positionMs ~/ 1000),
                    value: state.positionMs.toDouble(),
                    max: total.toDouble(),
                    onChanged: (value) => actions.seek(value.round()),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          if (state.playing) {
                            actions.pause();
                          } else {
                            actions.play();
                          }
                        },
                        icon: Icon(
                          state.playing ? Icons.pause : Icons.play_arrow,
                        ),
                        label: Text(state.playing ? '일시정지' : '재생'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => actions.seek(0),
                        icon: const Icon(Icons.replay),
                        label: const Text('처음으로'),
                      ),
                      OutlinedButton(
                        onPressed: () => actions.seek(
                          frame.startMs +
                              (frame.durationMs - 3000).clamp(
                                0,
                                frame.durationMs,
                              ),
                        ),
                        child: const Text('마지막 3초'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          final blocks = effectiveIntervalBlocks(module);
                          var start = 0;
                          for (final block in blocks) {
                            if (block.restSeconds > 0 && block.sets > 1) {
                              actions.seek(start + block.workSeconds * 1000);
                              return;
                            }
                            start += intervalBlockDuration(block) * 1000;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('이 슬라이드에는 휴식 구간이 없습니다.'),
                            ),
                          );
                        },
                        child: const Text('휴식으로'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => sound(
                          frame.isRest
                              ? (workout?.restStartSound ??
                                    WorkoutSound.lowPulse)
                              : (workout?.workStartSound ??
                                    WorkoutSound.sharpBeep),
                        ),
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('전환음 듣기'),
                      ),
                    ],
                  ),
                  if (soundError.value != null)
                    Text(
                      soundError.value!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
