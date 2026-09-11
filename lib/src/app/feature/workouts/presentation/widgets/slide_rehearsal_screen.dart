import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
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
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';

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
    final preview = AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
    );
    final controls = _RehearsalControls(
      frame: frame,
      state: state,
      totalMs: total,
      soundError: soundError.value,
      onTogglePlayback: () {
        if (state.playing) {
          actions.pause();
        } else {
          actions.play();
        }
      },
      onSeek: actions.seek,
      onLastSeconds: () => actions.seek(
        frame.startMs + (frame.durationMs - 3000).clamp(0, frame.durationMs),
      ),
      onRest: () {
        final blocks = effectiveIntervalBlocks(module);
        var start = 0;
        for (final block in blocks) {
          if (block.restSeconds > 0 && block.sets > 1) {
            actions.seek(start + block.workSeconds * 1000);
            return;
          }
          start += intervalBlockDuration(block) * 1000;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이 슬라이드에는 휴식 구간이 없습니다.')));
      },
      onSound: () => sound(
        frame.isRest
            ? (workout?.restStartSound ?? WorkoutSound.lowPulse)
            : (workout?.workStartSound ?? WorkoutSound.sharpBeep),
      ),
    );
    return Theme(
      data: SlideEditorStyle.theme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '슬라이드 시험 재생',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sideBySide =
                      constraints.maxWidth >= 1100 ||
                      (constraints.maxWidth >= 760 &&
                          constraints.maxHeight < 600);
                  final header = _RehearsalHeader(
                    name: module.name,
                    playing: state.playing,
                    complete: state.positionMs >= total && total > 0,
                  );
                  if (sideBySide) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: Row(
                        key: const ValueKey('rehearsal-wide-layout'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                header,
                                const SizedBox(height: 20),
                                Expanded(child: Center(child: preview)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 320,
                            child: SingleChildScrollView(
                              key: const ValueKey('rehearsal-controls-scroll'),
                              child: controls,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    key: const ValueKey('rehearsal-page-scroll'),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: 24),
                        preview,
                        const SizedBox(height: 24),
                        controls,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RehearsalHeader extends StatelessWidget {
  const _RehearsalHeader({
    required this.name,
    required this.playing,
    required this.complete,
  });
  final String name;
  final bool playing, complete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              name.isEmpty ? '미리보기' : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppStyle.of(context).subText1,
            ),
          ),
          const SizedBox(width: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: SlideEditorStyle.surface,
              borderRadius: BorderRadius.circular(AppStyle.controlRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                complete
                    ? '재생 완료'
                    : playing
                    ? '재생 중'
                    : '일시정지 중',
                style: const TextStyle(
                  color: SlideEditorStyle.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      const Text(
        '이 기기에서만 재생됩니다. 실제 수업에는 반영되지 않습니다.',
        style: TextStyle(
          color: SlideEditorStyle.muted,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ],
  );
}

class _RehearsalControls extends StatelessWidget {
  const _RehearsalControls({
    required this.frame,
    required this.state,
    required this.totalMs,
    required this.onTogglePlayback,
    required this.onSeek,
    required this.onLastSeconds,
    required this.onRest,
    required this.onSound,
    required this.soundError,
  });
  final SlideRehearsalFrame frame;
  final RehearsalState state;
  final int totalMs;
  final VoidCallback onTogglePlayback, onLastSeconds, onRest, onSound;
  final ValueChanged<int> onSeek;
  final String? soundError;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: SlideEditorStyle.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                frame.isRest
                    ? Icons.spa_outlined
                    : Icons.fitness_center_rounded,
                size: 22,
                color: SlideEditorStyle.accent,
              ),
              const SizedBox(width: 10),
              Text(
                frame.isRest ? '휴식' : '운동',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '블록 ${frame.blockIndex + 1} · ${frame.set}/${frame.totalSets}세트',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: SlideEditorStyle.muted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text(
                '재생 위치',
                style: TextStyle(color: SlideEditorStyle.muted, fontSize: 13),
              ),
              Text(
                '${durationLabel(state.positionMs ~/ 1000)} / ${durationLabel(totalMs ~/ 1000)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('rehearsal-seek'),
            label: durationLabel(state.positionMs ~/ 1000),
            semanticFormatterCallback: (value) =>
                '재생 위치 ${durationLabel(value.round() ~/ 1000)}',
            value: state.positionMs.toDouble(),
            max: totalMs.toDouble(),
            onChanged: (value) => onSeek(value.round()),
          ),
          const SizedBox(height: 8),
          _ControlPair(
            children: [
              FilledButton.icon(
                onPressed: onTogglePlayback,
                icon: Icon(
                  state.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(state.playing ? '일시정지' : '재생'),
              ),
              OutlinedButton.icon(
                onPressed: () => onSeek(0),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('처음으로'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ControlPair(
            children: [
              OutlinedButton(
                onPressed: onLastSeconds,
                child: const Text('마지막 3초'),
              ),
              OutlinedButton(onPressed: onRest, child: const Text('휴식으로')),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: onSound,
            icon: const Icon(Icons.volume_up_outlined),
            label: const Text('전환음 듣기'),
          ),
          if (soundError != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                soundError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ControlPair extends StatelessWidget {
  const _ControlPair({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stack =
          constraints.maxWidth < 260 ||
          MediaQuery.textScalerOf(context).scale(14) > 20;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(
              width: stack
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: child,
              ),
            ),
        ],
      );
    },
  );
}
