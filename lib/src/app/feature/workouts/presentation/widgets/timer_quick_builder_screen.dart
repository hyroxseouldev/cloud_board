import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/emom_builder_screen.dart';

class TimerQuickBuilderScreen extends StatelessWidget {
  const TimerQuickBuilderScreen({super.key, required this.module});
  final WorkoutModule module;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('타이머 간편 만들기')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '운동 방식을 선택하세요',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('적용 전에는 기존 타이머가 바뀌지 않습니다.'),
          const SizedBox(height: 20),
          for (final entry in const {
            WorkoutTimerMode.emom: '일정한 간격마다 다음 구간 시작',
            WorkoutTimerMode.amrap: '정해진 시간 동안 최대한 많은 반복',
            WorkoutTimerMode.forTime: '정해진 운동을 끝내는 데 걸린 시간',
            WorkoutTimerMode.tabata: '운동 20초 · 휴식 10초 · 8회',
            WorkoutTimerMode.interval: '운동·휴식 시간과 반복 수를 자유롭게',
          }.entries)
            Card(
              child: ListTile(
                key: ValueKey('timer-mode-${entry.key.name}'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                title: Text(
                  timerModeLabel(entry.key),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(entry.value),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  var result = await Navigator.of(context).push<WorkoutModule>(
                    MaterialPageRoute(
                      builder: (_) => entry.key == WorkoutTimerMode.emom
                          ? EmomBuilderScreen(module: module)
                          : TimerPresetEditor(module: module, mode: entry.key),
                    ),
                  );
                  if (result == null || !context.mounted) return;
                  if (entry.key == WorkoutTimerMode.emom) {
                    result = result.copyWith(
                      timingVersion: 3,
                      timerMode: WorkoutTimerMode.emom,
                    );
                  }
                  Navigator.pop(context, result);
                },
              ),
            ),
        ],
      ),
    ),
  );
}

class TimerPresetEditor extends HookWidget {
  const TimerPresetEditor({
    super.key,
    required this.module,
    required this.mode,
  });
  final WorkoutModule module;
  final WorkoutTimerMode mode;

  @override
  Widget build(BuildContext context) {
    final continuous =
        mode == WorkoutTimerMode.amrap || mode == WorkoutTimerMode.forTime;
    final forTime = mode == WorkoutTimerMode.forTime;
    final same = module.timerMode == mode;
    final block = effectiveIntervalBlocks(module).first;
    final work = useTextEditingController(
      text: formatSlideTime(
        same
            ? (forTime && module.workSeconds == 0 ? 600 : block.workSeconds)
            : mode == WorkoutTimerMode.tabata
            ? 20
            : continuous
            ? 600
            : 45,
      ),
    );
    final rest = useTextEditingController(
      text: formatSlideTime(
        same
            ? block.restSeconds
            : mode == WorkoutTimerMode.tabata
            ? 10
            : 15,
      ),
    );
    final repeats = useTextEditingController(
      text:
          '${same
              ? block.sets
              : mode == WorkoutTimerMode.tabata
              ? 8
              : 10}',
    );
    final capped = useState(same ? !isOpenEndedTimer(module) : !forTime);
    final finalRest = useState(same ? module.includeFinalRest : true);
    final direction = useState(
      same
          ? module.timerDirection
          : forTime
          ? TimerDirection.up
          : TimerDirection.down,
    );
    for (final c in [work, rest, repeats]) {
      useListenable(c);
    }
    final seconds = parseSlideTime(work.text);
    final restSeconds = parseSlideTime(rest.text);
    final count = int.tryParse(repeats.text);
    final workError =
        (!forTime || capped.value) && (seconds == null || seconds <= 0)
        ? '00:01~999:59로 입력해 주세요.'
        : null;
    final restError = !continuous && restSeconds == null
        ? '00:00~999:59로 입력해 주세요.'
        : null;
    final countError =
        !continuous && (count == null || count < 1 || count > 999)
        ? '1~999회로 입력해 주세요.'
        : null;
    WorkoutModule? proposed;
    String? error;
    if (workError == null && restError == null && countError == null) {
      try {
        proposed = continuous
            ? createContinuousTimer(
                module,
                mode: mode,
                seconds: forTime && !capped.value ? 0 : seconds!,
                direction: forTime && !capped.value
                    ? TimerDirection.up
                    : direction.value,
              )
            : createIntervalTimer(
                module,
                workSeconds: seconds!,
                restSeconds: restSeconds!,
                repeats: count!,
                includeFinalRest: finalRest.value,
                tabata:
                    mode == WorkoutTimerMode.tabata &&
                    seconds == 20 &&
                    restSeconds == 10 &&
                    count == 8 &&
                    finalRest.value,
              );
      } on FormatException catch (e) {
        error = e.message;
      }
    }
    Widget field(
      String key,
      String label,
      TextEditingController controller,
      String? error, {
      bool time = true,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        key: ValueKey(key),
        controller: controller,
        keyboardType: time ? TextInputType.datetime : TextInputType.number,
        inputFormatters: [
          time
              ? FilteringTextInputFormatter.allow(RegExp('[0-9:]'))
              : FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: label,
          helperText: time ? '분:초 · 예: 02:00' : null,
          errorText: error,
          border: const OutlineInputBorder(),
        ),
      ),
    );
    final result = proposed;
    return Scaffold(
      appBar: AppBar(
        title: Text('${timerModeLabel(mode)} 만들기'),
        actions: [
          TextButton(
            key: const ValueKey('apply-timer-preset'),
            onPressed: result == null
                ? null
                : () => Navigator.pop(context, result),
            child: const Text('적용'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result != null)
                Text(
                  moduleDurationText(result),
                  key: const ValueKey('preset-total'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (error != null)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const Text(
                '적용하면 기존 타이머를 대체합니다. 슬라이드 저장을 눌러 저장하세요.',
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
            Text(
              forTime
                  ? '운동 완료를 누르면 시간이 멈춥니다. 제한시간에 도달하면 멈춘 상태로 결과를 확인합니다.'
                  : continuous
                  ? '설정한 시간이 끝나면 다음 슬라이드로 진행합니다. 그동안 최대한 많은 라운드·반복을 수행하세요.'
                  : '운동과 휴식을 번갈아 반복합니다. 각 구간이 끝나면 다음 구간이 시작됩니다.',
            ),
            const SizedBox(height: 24),
            if (forTime)
              SwitchListTile.adaptive(
                key: const ValueKey('preset-time-cap'),
                contentPadding: EdgeInsets.zero,
                title: const Text('제한시간 사용'),
                value: capped.value,
                onChanged: (value) => capped.value = value,
              ),
            if (!forTime || capped.value)
              field(
                'preset-work',
                forTime
                    ? '제한시간'
                    : continuous
                    ? '운동 시간'
                    : '구간당 운동 시간',
                work,
                workError,
              ),
            if (!continuous) ...[
              field('preset-rest', '구간당 휴식 시간', rest, restError),
              field(
                'preset-repeats',
                '반복 횟수 (1~999)',
                repeats,
                countError,
                time: false,
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('preset-final-rest'),
                contentPadding: EdgeInsets.zero,
                title: const Text('마지막 운동 뒤에도 휴식'),
                value: finalRest.value,
                onChanged: (value) => finalRest.value = value,
              ),
              if (mode == WorkoutTimerMode.tabata &&
                  result?.timerMode == WorkoutTimerMode.interval)
                const Text('시간·반복을 바꾼 구성은 인터벌로 저장합니다.'),
            ],
            if (continuous && (!forTime || capped.value)) ...[
              const Text('시간 표시'),
              const SizedBox(height: 8),
              SegmentedButton<TimerDirection>(
                segments: const [
                  ButtonSegment(
                    value: TimerDirection.down,
                    label: Text('남은 시간'),
                  ),
                  ButtonSegment(value: TimerDirection.up, label: Text('경과 시간')),
                ],
                selected: {direction.value},
                onSelectionChanged: (value) => direction.value = value.single,
              ),
            ],
            if (forTime && !capped.value) const Text('00:00부터 경과 시간을 표시합니다.'),
            if (result != null && !continuous)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  '[운동 ${work.text} → 휴식 ${rest.text}] × ${repeats.text}회${finalRest.value ? '' : ' · 마지막 휴식 제외'}',
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              '준비 카운트다운은 수업 설정을 따르며 합계에 포함되지 않습니다.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
