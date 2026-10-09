import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_editing.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';

class SlideTimerSummary extends StatelessWidget {
  const SlideTimerSummary({
    super.key,
    required this.module,
    required this.onEdit,
    this.dirty = false,
  });
  final WorkoutModule module;
  final VoidCallback onEdit;
  final bool dirty;
  @override
  Widget build(BuildContext context) {
    final rest = timerRestDescription(module);
    return Material(
      color: SlideEditorStyle.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: SlideEditorStyle.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('slide-timer-summary'),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 20,
                    color: SlideEditorStyle.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timerEditorLabel(module),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Text(
                    '편집',
                    style: TextStyle(
                      fontSize: 14,
                      color: SlideEditorStyle.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: SlideEditorStyle.accent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, box) {
                  final total = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '총 소요 시간',
                        style: TextStyle(
                          fontSize: 12,
                          color: SlideEditorStyle.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        moduleDurationText(module),
                        key: const ValueKey('slide-timer-total'),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: SlideEditorStyle.accent,
                        ),
                      ),
                    ],
                  );
                  final detail = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isContinuousTimer(module) ? '진행 방식' : '반복 구성',
                        style: const TextStyle(
                          fontSize: 12,
                          color: SlideEditorStyle.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timerComposition(module),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timerRepeatDescription(module),
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (rest != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          rest,
                          style: const TextStyle(
                            fontSize: 12,
                            color: SlideEditorStyle.muted,
                          ),
                        ),
                      ],
                    ],
                  );
                  if (box.maxWidth < 310 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20 ||
                      module.timerMode == WorkoutTimerMode.forTime) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [total, const SizedBox(height: 12), detail],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: total),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: detail),
                    ],
                  );
                },
              ),
              if (dirty) ...[
                const SizedBox(height: 12),
                const Text(
                  '저장 전 변경',
                  key: ValueKey('timer-unsaved-status'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SlideEditorStyle.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TimerResultSummary extends StatelessWidget {
  const TimerResultSummary({
    super.key,
    required this.module,
    required this.onRehearse,
  });
  final WorkoutModule module;
  final VoidCallback onRehearse;
  @override
  Widget build(BuildContext context) {
    final phases = workoutModuleTimeline(module);
    final blocks = effectiveIntervalBlocks(module);
    final single = blocks.length == 1 && !hasRoundTiming(module);
    final firstRound = phases.where((p) => p.round == 1);
    final preview =
        (single
                ? phases.take(
                    blocks.first.workSeconds == 0 ||
                            blocks.first.restSeconds == 0
                        ? 1
                        : 2,
                  )
                : firstRound.take(6))
            .toList();
    final work = workoutModuleWorkSeconds(module);
    final rest = workoutModuleDuration(module) - work;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SlideEditorStyle.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final label = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '총 소요 시간',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isContinuousTimer(module)) ...[
                    const SizedBox(height: 4),
                    Text(
                      '운동 ${formatSlideTime(work)} · 휴식 ${formatSlideTime(rest)}',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: SlideEditorStyle.muted,
                      ),
                    ),
                  ],
                ],
              );
              final total = Text(
                moduleDurationText(module),
                key: const ValueKey('timer-editor-total'),
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: SlideEditorStyle.accent,
                ),
              );
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20 ||
                  isOpenEndedTimer(module)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, const SizedBox(height: 8), total],
                );
              }
              return Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: total,
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 20),
          const Text(
            '진행 순서',
            style: TextStyle(
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (isContinuousTimer(module))
            Text(timerComposition(module))
          else
            Wrap(
              spacing: 6,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < preview.length; i++) ...[
                  if (i > 0)
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: SlideEditorStyle.muted,
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SlideEditorStyle.line),
                    ),
                    child: Text(
                      '${preview[i].isRest ? '휴식' : '운동'}\n${formatSlideTime(preview[i].seconds)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, height: 1.2),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 8),
          if (isContinuousTimer(module) ||
              blocks.length > 1 ||
              blocks.first.sets > 1 ||
              hasRoundTiming(module))
            Text(
              timerRepeatDescription(module),
              style: const TextStyle(
                fontSize: 12,
                color: SlideEditorStyle.muted,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (!isContinuousTimer(module) &&
                    phases.length > preview.length)
                  TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      useSafeArea: true,
                      isScrollControlled: true,
                      constraints: const BoxConstraints(maxWidth: 600),
                      builder: (_) => SizedBox(
                        height: MediaQuery.sizeOf(context).height * .7,
                        child: Column(
                          children: [
                            ListTile(
                              title: Text('전체 진행 순서 · ${phases.length}구간'),
                              trailing: const CloseButton(),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: phases.length,
                                itemBuilder: (_, i) => ListTile(
                                  leading: Text('${i + 1}'),
                                  title: Text(
                                    '${phases[i].isRest ? '휴식' : '운동'} ${formatSlideTime(phases[i].seconds)}',
                                  ),
                                  subtitle: Text(phases[i].positionLabel),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    child: const Text('전체 순서 보기'),
                  ),
                TextButton.icon(
                  key: const ValueKey('timer-rehearse'),
                  onPressed: onRehearse,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('시험 재생'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<WorkoutTimerMode?> showTimerModePicker(
  BuildContext context, {
  required WorkoutTimerMode current,
  bool creating = false,
}) => showModalBottomSheet<WorkoutTimerMode>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 600),
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    creating ? '운동 방식을 선택하세요' : '타이머 방식 변경',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const CloseButton(),
              ],
            ),
            for (final mode in [
              WorkoutTimerMode.emom,
              WorkoutTimerMode.amrap,
              WorkoutTimerMode.forTime,
              WorkoutTimerMode.tabata,
              WorkoutTimerMode.interval,
              WorkoutTimerMode.custom,
            ])
              ListTile(
                key: ValueKey('timer-mode-${mode.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  mode == WorkoutTimerMode.custom
                      ? '직접 구성'
                      : timerModeLabel(mode),
                ),
                subtitle: Text(
                  timerModeDescription(mode),
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: Icon(
                  mode == current ? Icons.check : Icons.chevron_right,
                  color: SlideEditorStyle.accent,
                ),
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      ),
    ),
  ),
);

Future<bool> confirmTimerReplacement(
  BuildContext context,
  WorkoutModule before,
  WorkoutModule after,
) async =>
    await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '타이머 방식 변경',
                        style: TextStyle(
                          color: SlideEditorStyle.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const CloseButton(),
                  ],
                ),
                Text(
                  '${timerEditorLabel(after)}으로 바꿀까요?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isContinuousTimer(before)
                      ? '시간과 종료 방식이 새 타이머 설정으로 바뀝니다.'
                      : '현재 구간과 반복·휴식 설정이 새 타이머로 바뀝니다.',
                ),
                const SizedBox(height: 20),
                for (final entry in [('현재', before), ('변경 후', after)])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SlideEditorStyle.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.$1} · ${timerEditorLabel(entry.$2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            moduleDurationText(entry.$2),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: SlideEditorStyle.accent,
                            ),
                          ),
                          Text(timerComposition(entry.$2)),
                          Text(
                            timerRepeatDescription(entry.$2),
                            style: const TextStyle(
                              fontSize: 13,
                              color: SlideEditorStyle.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Text(
                  '슬라이드는 아직 저장되지 않아요.',
                  style: TextStyle(fontSize: 13, color: SlideEditorStyle.muted),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('confirm-timer-replacement'),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('구성 교체'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ) ??
    false;
