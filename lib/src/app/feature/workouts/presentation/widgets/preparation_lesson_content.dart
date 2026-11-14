import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shadcn;

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';

/// Mixed capped/open timers must not imply a fixed duration for the capped part.
String preparationDurationText(Workout workout) {
  final text = workoutDurationText(workout);
  final mixedCaps =
      workout.modules.any(isOpenEndedTimer) &&
      workout.modules.any(
        (m) => m.timerMode == WorkoutTimerMode.forTime && !isOpenEndedTimer(m),
      );
  return mixedCaps ? '최대 $text' : text;
}

String preparationTimerKinds(Workout workout) => workout.modules
    .map((module) => timerModeLabel(module.timerMode))
    .toSet()
    .join(' · ');

/// Describe configured intervals, using the same effective blocks/rest rule as
/// playback. Never fetch images or expand the timeline into a second UI model.
List<String> preparationModuleDetails(WorkoutModule module) {
  if (isContinuousTimer(module)) {
    return [
      if (isOpenEndedTimer(module))
        '경과 시간을 표시해요.'
      else if (module.timerMode == WorkoutTimerMode.forTime)
        '제한시간 ${durationLabel(module.workSeconds)} · ${timerCountsUp(module) ? '경과' : '남은'} 시간 표시'
      else
        '연속 운동 ${durationLabel(module.workSeconds)}',
    ];
  }
  final blocks = effectiveIntervalBlocks(module);
  final uniform = blocks.every(
    (block) =>
        block.workSeconds == blocks.first.workSeconds &&
        block.restSeconds == blocks.first.restSeconds &&
        blockHasRest(module, block, block.sets) ==
            blockHasRest(module, blocks.first, blocks.first.sets),
  );
  String describe(WorkoutIntervalBlock block, int sets) => [
    '$sets${module.timerMode == WorkoutTimerMode.emom ? '구간' : '세트'}',
    if (block.workSeconds > 0)
      '${module.timerMode == WorkoutTimerMode.emom ? '구간' : '운동'} ${durationLabel(block.workSeconds)}',
    if (block.restSeconds > 0) '휴식 ${durationLabel(block.restSeconds)}',
  ].join(' · ');
  return [
    if (uniform)
      describe(blocks.first, blocks.fold(0, (sum, b) => sum + b.sets))
    else
      for (var i = 0; i < blocks.length; i++)
        '${i + 1}번 블록: ${describe(blocks[i], blocks[i].sets)}',
    if (blocks.any(
      (b) => b.restSeconds > 0 && !blockHasRest(module, b, b.sets),
    ))
      blocks.length == 1 ? '마지막 세트 휴식 제외' : '각 블록 마지막 세트 휴식 제외',
    if (module.timingVersion >= 2 && hasRoundTiming(module))
      [
        '${module.rounds}라운드',
        if (module.roundRestSeconds > 0)
          '라운드 휴식 ${durationLabel(module.roundRestSeconds)}',
        if (module.roundRestSeconds > 0 && !module.includeFinalRoundRest)
          '마지막 라운드 휴식 제외',
      ].join(' · '),
  ];
}

/// Text-only ordered composition remains the last section of preparation.
class PreparationLessonComposition extends StatelessWidget {
  const PreparationLessonComposition({super.key, required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    if (workout.modules.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('수업 구성', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '아래 순서대로 진행해요.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        shadcn.ShadCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < workout.modules.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _ModuleRow(module: workout.modules[i], index: i),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module, required this.index});
  final WorkoutModule module;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('preparation-module-$index'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}'.padLeft(2, '0'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${timerModeLabel(module.timerMode)} · ${moduleDurationText(module)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final detail in preparationModuleDetails(module))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
