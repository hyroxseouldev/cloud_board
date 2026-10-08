import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';

class EmomBuilderScreen extends HookWidget {
  const EmomBuilderScreen({super.key, required this.module});
  final WorkoutModule module;

  @override
  Widget build(BuildContext context) {
    final initial = useMemoized(() => emomConfiguration(module));
    final duration = useTextEditingController(
      text: formatSlideTime(initial?.seconds ?? 60),
    );
    final intervals = useTextEditingController(
      text: '${initial?.intervals ?? 1}',
    );
    final rest = useTextEditingController(
      text: formatSlideTime(initial?.restSeconds ?? 0),
    );
    final rounds = useTextEditingController(text: '${initial?.rounds ?? 10}');
    final finalRest = useState(initial?.includeFinalRest ?? true);
    for (final controller in [duration, intervals, rest, rounds]) {
      useListenable(controller);
    }
    final seconds = parseSlideTime(duration.text);
    final intervalCount = int.tryParse(intervals.text);
    final restSeconds = parseSlideTime(rest.text);
    final roundCount = int.tryParse(rounds.text);
    final fieldErrors = <String, String?>{
      'emom-duration': seconds == null || seconds <= 0
          ? '00:01~999:59로 입력해 주세요.'
          : null,
      'emom-intervals':
          intervalCount == null ||
              intervalCount < 1 ||
              intervalCount > maxTimingBlocks
          ? '1~100개로 입력해 주세요.'
          : null,
      'emom-rest': restSeconds == null ? '00:00~999:59로 입력해 주세요.' : null,
      'emom-rounds':
          roundCount == null || roundCount < 1 || roundCount > maxTimingRepeats
          ? '1~999회로 입력해 주세요.'
          : null,
    };
    WorkoutModule? candidate;
    String? error;
    try {
      candidate = createEmom(module, (
        seconds: seconds ?? -1,
        intervals: intervalCount ?? 0,
        rounds: roundCount ?? 0,
        restSeconds: restSeconds ?? -1,
        includeFinalRest: finalRest.value,
      ));
    } on FormatException catch (e) {
      error = e.message;
    }
    void preset({
      required int seconds,
      required int count,
      required int pause,
      required int repeat,
    }) {
      duration.text = formatSlideTime(seconds);
      intervals.text = '$count';
      rest.text = formatSlideTime(pause);
      rounds.text = '$repeat';
      finalRest.value = true;
    }

    Widget field(
      String key,
      String label,
      TextEditingController controller, {
      bool time = false,
    }) => TextField(
      key: ValueKey(key),
      controller: controller,
      keyboardType: time ? TextInputType.datetime : TextInputType.number,
      inputFormatters: time
          ? [FilteringTextInputFormatter.allow(RegExp('[0-9:]'))]
          : [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        helperText: time ? '분:초 · 예: 02:00' : null,
        errorText: fieldErrors[key],
        border: const OutlineInputBorder(),
      ),
    );
    final proposed = candidate;
    return Scaffold(
      key: const ValueKey('emom-builder'),
      appBar: AppBar(
        title: const Text('EMOM 간편 만들기'),
        leading: CloseButton(onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            key: const ValueKey('apply-emom'),
            onPressed: proposed == null
                ? null
                : () => Navigator.pop(context, proposed),
            child: const Text('적용'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error != null)
                Text(
                  error,
                  key: const ValueKey('emom-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (proposed != null) ...[
                Text(
                  '총 ${durationLabel(workoutModuleDuration(proposed))}',
                  key: const ValueKey('emom-total'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '운동 ${durationLabel(workoutModuleWorkSeconds(proposed))} · '
                  '휴식 ${durationLabel(workoutModuleDuration(proposed) - workoutModuleWorkSeconds(proposed))}',
                ),
                Text(
                  '운동 ${workoutModuleTimeline(proposed).where((p) => !p.isRest).length}구간 · '
                  '휴식 ${workoutModuleTimeline(proposed).where((p) => p.isRest).length}구간',
                ),
              ],
              const Text(
                '적용 시 기존 타이머가 이 설정으로 바뀝니다.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              '일정한 간격으로 시작하는 타이머',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('구간 시간이 끝나면 다음 구간을 시작합니다. 1분 외의 간격도 만들 수 있어요.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  key: const ValueKey('emom-preset-minute'),
                  label: const Text('1분 간격 × 10회'),
                  onPressed: () =>
                      preset(seconds: 60, count: 1, pause: 0, repeat: 10),
                ),
                ActionChip(
                  key: const ValueKey('emom-preset-rounds'),
                  label: const Text('2분 × 3구간 · 휴식 30초 · 6라운드'),
                  onPressed: () =>
                      preset(seconds: 120, count: 3, pause: 30, repeat: 6),
                ),
              ],
            ),
            if (initial == null)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('현재는 사용자 지정 구성입니다. 적용하면 아래 설정으로 타이머를 새로 만듭니다.'),
              ),
            const SizedBox(height: 24),
            field('emom-duration', '구간 시간', duration, time: true),
            const SizedBox(height: 16),
            field('emom-intervals', '라운드당 구간 수 (1~100)', intervals),
            const SizedBox(height: 16),
            field('emom-rest', '라운드 휴식', rest, time: true),
            const SizedBox(height: 16),
            field('emom-rounds', '라운드 반복 (1~999)', rounds),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              key: const ValueKey('emom-final-rest'),
              contentPadding: EdgeInsets.zero,
              title: const Text('마지막 라운드 뒤에도 휴식'),
              subtitle: parseSlideTime(rest.text) == 0
                  ? const Text('휴식 0초에서는 총시간이 같습니다.')
                  : null,
              value: finalRest.value,
              onChanged: (value) => finalRest.value = value,
            ),
            const Divider(height: 32),
            if (proposed != null) ...[
              Text(
                '${duration.text} 간격 · ${intervals.text}구간 × ${rounds.text}라운드',
                key: const ValueKey('emom-sequence'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '[${List.filled(int.parse(intervals.text).clamp(1, 5), duration.text).join(' → ')}'
                '${int.parse(intervals.text) > 5 ? ' → …' : ''}'
                '${proposed.roundRestSeconds > 0 ? ' → 휴식 ${rest.text}' : ''}] × ${rounds.text}라운드',
              ),
              const SizedBox(height: 8),
              if (!finalRest.value && proposed.roundRestSeconds > 0)
                const Text('마지막 라운드의 휴식은 생략합니다.'),
            ],
            const SizedBox(height: 16),
            const Text(
              '적용하면 기존 타이머 구성을 대체합니다. 적용 후 직접 수정할 수 있으며, 슬라이드 저장 버튼을 눌러 저장해 주세요. 준비 카운트다운은 별도입니다.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
