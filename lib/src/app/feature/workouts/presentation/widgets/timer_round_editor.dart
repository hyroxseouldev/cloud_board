import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_duration_field.dart';

class TimerRoundEditor extends HookWidget {
  const TimerRoundEditor({
    super.key,
    required this.module,
    required this.onChanged,
  });
  final WorkoutModule module;
  final ValueChanged<WorkoutModule> onChanged;

  @override
  Widget build(BuildContext context) {
    final rounds = useTextEditingController(text: '${module.rounds}');
    final rest = useTextEditingController(
      text: formatSlideTime(module.roundRestSeconds),
    );
    useEffect(() {
      rounds.text = '${module.rounds}';
      rest.text = formatSlideTime(module.roundRestSeconds);
      return null;
    }, [module.rounds, module.roundRestSeconds]);
    return ExpansionTile(
      key: const ValueKey('timer-round-settings'),
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: hasRoundTiming(module),
      title: const Text('전체 구간 반복'),
      subtitle: Text(
        '${module.rounds}라운드 · 라운드 휴식 ${formatSlideTime(module.roundRestSeconds)}',
      ),
      children: [
        const Text('아래 블록을 순서대로 마친 뒤 라운드 휴식을 갖고 다시 시작합니다.'),
        const SizedBox(height: 12),
        SlideSetCountField(
          controller: rounds,
          label: '라운드 반복',
          unit: '회',
          validator: (_) => null,
          onChanged: (value) =>
              onChanged(module.copyWith(timingVersion: 2, rounds: value)),
        ),
        const SizedBox(height: 8),
        SlideDurationField(
          controller: rest,
          label: '라운드 휴식',
          minimumSeconds: 0,
          validator: (_) => null,
          onChanged: (value) => onChanged(
            module.copyWith(timingVersion: 2, roundRestSeconds: value),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          key: const ValueKey('round-final-rest'),
          title: const Text('마지막 라운드 뒤에도 휴식'),
          value: module.includeFinalRoundRest,
          onChanged: (value) => onChanged(
            module.copyWith(timingVersion: 2, includeFinalRoundRest: value),
          ),
        ),
      ],
    );
  }
}
