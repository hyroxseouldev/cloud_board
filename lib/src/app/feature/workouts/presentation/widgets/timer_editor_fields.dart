import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_editing.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/timer_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/timer_duration_wheel.dart';

class TimerCountField extends HookWidget {
  const TimerCountField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.stepper = false,
    this.unit,
    this.maximum = 999,
  });
  final String fieldKey, label;
  final int value, maximum;
  final bool stepper;
  final String? error, unit;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final formatted = '$value';
    final controller = useTextEditingController(text: formatted);
    final focus = useFocusNode();
    useEffect(() {
      if (!focus.hasFocus && error == null && controller.text != formatted) {
        controller.text = formatted;
      }
      return null;
    }, [formatted, error]);
    final input = Semantics(
      label: label,
      child: TextField(
        key: ValueKey(fieldKey),
        controller: controller,
        focusNode: focus,
        textAlign: stepper ? TextAlign.center : TextAlign.start,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: stepper ? 18 : 26,
          height: 1.15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: '1',
          suffixText: stepper ? '회' : unit ?? '회',
          suffixStyle: const TextStyle(
            fontSize: 12,
            color: SlideEditorStyle.muted,
          ),
          errorText: stepper ? null : error,
          errorMaxLines: 3,
          contentPadding: EdgeInsets.symmetric(
            horizontal: stepper ? 4 : 14,
            vertical: 12,
          ),
          filled: true,
          fillColor: SlideEditorStyle.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: stepper
                  ? Colors.transparent
                  : SlideEditorStyle.controlBorder,
            ),
          ),
        ),
        onChanged: onChanged,
      ),
    );
    final title = Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
    if (stepper) {
      void step(int delta) {
        focus.unfocus();
        controller.text = '${value + delta}';
        onChanged(controller.text);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 16),
          Row(
            children: [
              Expanded(child: title),
              IconButton.filledTonal(
                key: ValueKey('$fieldKey-decrease'),
                tooltip: '$label 줄이기',
                onPressed: value > 1 && error == null ? () => step(-1) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(width: 64, child: input),
              IconButton.filledTonal(
                key: ValueKey('$fieldKey-increase'),
                tooltip: '$label 늘리기',
                onPressed: value < maximum && error == null
                    ? () => step(1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          const Divider(height: 16),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, const SizedBox(height: 8), input],
    );
  }
}

class TimerCompactFields extends StatelessWidget {
  const TimerCompactFields({
    super.key,
    required this.state,
    required this.actions,
    required this.selection,
  });
  final TimerEditorState state;
  final TimerEditorController actions;
  final TimerWheelSelection selection;
  @override
  Widget build(BuildContext context) {
    final m = state.module;
    final b = effectiveIntervalBlocks(m).first;
    final emom = state.inputMode == WorkoutTimerMode.emom;
    Widget field(String name, String label, int value, {String? unit}) =>
        TimerCountField(
          fieldKey: 'timer-$name',
          label: label,
          value: value,
          stepper: name == 'repeats',
          unit: unit,
          error: state.errors[name],
          onChanged: (raw) => actions.setInput(name, raw),
        );
    TimerDurationOption duration(String name, String label, int value) =>
        TimerDurationOption(
          fieldKey: 'timer-$name',
          label: label,
          seconds: value,
          minimumSeconds:
              name == 'interval' || (name == 'work' && isContinuousTimer(m))
              ? 1
              : 0,
          error: state.errors[name],
          onChanged: (seconds) =>
              actions.setInput(name, formatSlideTime(seconds)),
        );
    if (isContinuousTimer(m)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.timerMode == WorkoutTimerMode.forTime)
            SwitchListTile.adaptive(
              key: const ValueKey('preset-time-cap'),
              contentPadding: EdgeInsets.zero,
              title: const Text('제한시간 사용'),
              value: !isOpenEndedTimer(m),
              onChanged: (value) {
                selection.commit();
                actions.setCapped(value);
              },
            ),
          if (!isOpenEndedTimer(m)) ...[
            TimerDurationGroup(
              selection: selection,
              options: [
                duration(
                  'work',
                  m.timerMode == WorkoutTimerMode.forTime ? '제한시간' : '운동 시간',
                  m.workSeconds,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('시간 표시'),
            const SizedBox(height: 8),
            SegmentedButton<TimerDirection>(
              segments: const [
                ButtonSegment(value: TimerDirection.down, label: Text('남은 시간')),
                ButtonSegment(value: TimerDirection.up, label: Text('경과 시간')),
              ],
              selected: {m.timerDirection},
              showSelectedIcon: false,
              onSelectionChanged: (values) =>
                  actions.setDirection(values.single),
            ),
          ] else
            const Text('00:00부터 경과 시간을 표시해요. 운동 완료를 누르면 시간이 멈춥니다.'),
          const SizedBox(height: 16),
          Text(
            timerRepeatDescription(m),
            style: const TextStyle(color: SlideEditorStyle.muted, fontSize: 13),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TimerDurationGroup(
          selection: selection,
          options: [
            duration(
              emom ? 'interval' : 'work',
              emom ? '구간 시간' : '운동 시간',
              b.workSeconds,
            ),
            if (!emom) duration('rest', '휴식 시간', b.restSeconds),
          ],
        ),
        if (emom) ...[
          const SizedBox(height: 16),
          field(
            'intervals',
            '라운드당 구간 수',
            effectiveIntervalBlocks(m).length,
            unit: '개',
          ),
        ],
        const SizedBox(height: 20),
        if (emom)
          Column(
            children: [
              TimerDurationGroup(
                selection: selection,
                options: [duration('roundRest', '라운드 휴식', m.roundRestSeconds)],
              ),
              const SizedBox(height: 16),
              field('rounds', '전체 라운드', m.rounds),
            ],
          )
        else
          field('repeats', '반복 횟수', b.sets),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          key: ValueKey(emom ? 'emom-final-rest' : 'preset-final-rest'),
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.zero,
          title: Text(
            emom ? '마지막 라운드 뒤 휴식' : '마지막 운동 뒤 휴식',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            emom
                ? m.roundRestSeconds > 0
                      ? '라운드마다 ${formatSlideTime(m.roundRestSeconds)} 휴식해요.'
                      : '라운드 사이에 바로 이어서 진행해요.'
                : '마지막 반복 뒤에도 설정한 휴식을 진행해요.',
            style: const TextStyle(fontSize: 12),
          ),
          value: emom ? m.includeFinalRoundRest : m.includeFinalRest,
          onChanged: (value) => actions.setFinalRest(value, round: emom),
        ),
      ],
    );
  }
}

class TimerDetailedFields extends HookWidget {
  const TimerDetailedFields({
    super.key,
    required this.state,
    required this.actions,
    required this.selection,
  });
  final TimerEditorState state;
  final TimerEditorController actions;
  final TimerWheelSelection selection;
  @override
  Widget build(BuildContext context) {
    final m = state.module;
    final blocks = effectiveIntervalBlocks(m);
    final expanded = useState(blocks.first.id);
    final lastLength = useRef(blocks.length);
    useEffect(() {
      if (blocks.length > lastLength.value) {
        expanded.value = blocks.last.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            selection.select(
              '${blocks.last.id}-${blocks.last.workSeconds == 0 ? 'rest' : 'work'}',
            );
          }
        });
      }
      lastLength.value = blocks.length;
      return null;
    }, [blocks.length]);
    Widget field(String name, String label, int value, {String? id}) =>
        TimerCountField(
          fieldKey: id == null ? 'timer-$name' : '$id-$name',
          label: label,
          value: value,
          error: state.errors[id == null ? name : '$id-$name'],
          onChanged: (raw) => actions.setInput(name, raw, blockId: id),
        );
    TimerDurationOption duration(
      String name,
      String label,
      int value, {
      String? id,
    }) => TimerDurationOption(
      fieldKey: id == null ? 'timer-$name' : '$id-$name',
      label: label,
      seconds: value,
      error: state.errors[id == null ? name : '$id-$name'],
      onChanged: (seconds) =>
          actions.setInput(name, formatSlideTime(seconds), blockId: id),
    );
    void toggleBlock(WorkoutIntervalBlock block) {
      final next = expanded.value == block.id ? '' : block.id;
      selection.select(
        next.isEmpty
            ? null
            : '$next-${block.workSeconds == 0 ? 'rest' : 'work'}',
      );
      expanded.value = next;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: blocks.length,
          onReorderItem: (oldIndex, newIndex) {
            selection.commit();
            actions.reorder(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final b = blocks[index];
            final restOnly = b.workSeconds == 0 && b.restSeconds > 0;
            return Padding(
              key: ValueKey(b.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: SlideEditorStyle.surface,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Semantics(
                              label: '구간 ${index + 1} 순서 변경',
                              child: const Icon(Icons.drag_handle_rounded),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            key: ValueKey('timer-block-${b.id}'),
                            minTileHeight: 64,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              restOnly ? '휴식 ${index + 1}' : '구간 ${index + 1}',
                              style: const TextStyle(
                                letterSpacing: -0.16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${restOnly ? '휴식만 ${formatSlideTime(b.restSeconds)}' : '${formatSlideTime(b.workSeconds)} / 휴식 ${formatSlideTime(b.restSeconds)}'} · ${b.sets}회',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => toggleBlock(b),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: '구간 ${index + 1} 메뉴',
                          onSelected: (value) {
                            selection.select(null);
                            actions.blockAction(b.id, value);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'up',
                              enabled: index > 0,
                              child: const Text('위로 이동'),
                            ),
                            PopupMenuItem(
                              value: 'down',
                              enabled: index < blocks.length - 1,
                              child: const Text('아래로 이동'),
                            ),
                            PopupMenuItem(
                              value: 'duplicate',
                              enabled: blocks.length < maxTimingBlocks,
                              child: const Text('복제'),
                            ),
                            PopupMenuItem(
                              value: 'type',
                              child: Text(restOnly ? '운동 구간으로 변경' : '휴식만으로 변경'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              enabled: blocks.length > 1,
                              child: const Text('삭제'),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: expanded.value == b.id ? '구간 접기' : '구간 펼치기',
                          icon: Icon(
                            expanded.value == b.id
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          onPressed: () => toggleBlock(b),
                        ),
                      ],
                    ),
                    if (expanded.value == b.id)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            const Divider(height: 16),
                            TimerDurationGroup(
                              selection: selection,
                              options: [
                                if (!restOnly)
                                  duration(
                                    'work',
                                    '운동 시간',
                                    b.workSeconds,
                                    id: b.id,
                                  ),
                                duration(
                                  'rest',
                                  '휴식 시간',
                                  b.restSeconds,
                                  id: b.id,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            field('repeats', '이 구간 반복', b.sets, id: b.id),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        PopupMenuButton<bool>(
          tooltip: '구간 추가',
          enabled: blocks.length < maxTimingBlocks,
          onSelected: (restOnly) {
            selection.select(null);
            actions.addBlock(restOnly: restOnly);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: false,
              key: ValueKey('add-interval-block'),
              child: Text('운동·휴식 구간'),
            ),
            PopupMenuItem(
              value: true,
              key: ValueKey('add-rest-block'),
              child: Text('휴식만'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('구간 추가'),
              ],
            ),
          ),
        ),
        if (blocks.any((b) => b.workSeconds > 0 && b.restSeconds > 0))
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('각 구간의 마지막 운동 뒤 휴식'),
            subtitle: const Text('직접 추가한 휴식 구간은 항상 유지해요.'),
            value: m.includeFinalRest,
            onChanged: actions.setFinalRest,
          ),
        const Divider(height: 24),
        ExpansionTile(
          key: const ValueKey('timer-round-settings'),
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: hasRoundTiming(m),
          onExpansionChanged: (expanded) {
            if (!expanded && selection.selectedKey == 'timer-roundRest') {
              selection.select(null);
            }
          },
          title: const Text('전체 구성 반복'),
          subtitle: Text(
            '${m.rounds}라운드 · 라운드 휴식 ${formatSlideTime(m.roundRestSeconds)}',
          ),
          children: [
            const Text('위 구간을 순서대로 마친 뒤 쉬고, 같은 구성을 다시 시작해요.'),
            const SizedBox(height: 16),
            field('rounds', '전체 라운드', m.rounds),
            const SizedBox(height: 16),
            TimerDurationGroup(
              selection: selection,
              options: [duration('roundRest', '라운드 휴식', m.roundRestSeconds)],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('마지막 라운드 뒤 휴식'),
              value: m.includeFinalRoundRest,
              onChanged: (v) => actions.setFinalRest(v, round: true),
            ),
          ],
        ),
      ],
    );
  }
}
