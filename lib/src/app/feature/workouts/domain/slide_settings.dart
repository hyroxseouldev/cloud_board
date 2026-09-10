import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';

enum TimerDisplayMode { gaugeAndNumber, numberOnly, hidden }

TimerDisplayMode timerDisplayMode(WorkoutModule module) => !module.showTimer
    ? TimerDisplayMode.hidden
    : module.showTimerGauge
    ? TimerDisplayMode.gaugeAndNumber
    : TimerDisplayMode.numberOnly;

String formatSlideTime(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

int? parseSlideTime(String value) {
  if (!RegExp(r'^\d{2,}:[0-5]\d$').hasMatch(value)) return null;
  final parts = value.split(':');
  final minutes = int.tryParse(parts[0]);
  if (minutes == null || minutes > 999) return null;
  return minutes * 60 + int.parse(parts[1]);
}

String nextSlideName(Iterable<WorkoutModule> modules) {
  final names = modules.map((m) => m.name.trim()).toSet();
  var number = 1;
  while (names.contains('새 운동 $number')) {
    number++;
  }
  return '새 운동 $number';
}

int remainingSets({
  required int set,
  required int total,
  required bool isRest,
}) => (total - set + (isRest ? 0 : 1)).clamp(0, total);

List<WorkoutIntervalBlock> effectiveIntervalBlocks(WorkoutModule module) =>
    module.intervalBlocks.isNotEmpty
    ? module.intervalBlocks
    : [
        WorkoutIntervalBlock(
          id: '${module.id}-interval-1',
          workSeconds: module.workSeconds,
          restSeconds: module.restSeconds,
          sets: module.sets,
        ),
      ];

WorkoutModule withIntervalBlocks(
  WorkoutModule module,
  List<WorkoutIntervalBlock> blocks,
) {
  final first = blocks.first;
  return module.copyWith(
    workSeconds: first.workSeconds,
    restSeconds: first.restSeconds,
    sets: first.sets,
    intervalBlocks: blocks,
  );
}

int slideColor(
  WorkoutModule module, {
  required bool rest,
  required bool text,
  int? secondsLeft,
}) {
  final explicit = text
      ? (rest ? module.restTextColor : module.workTextColor)
      : (rest ? module.restGaugeColor : module.workGaugeColor);
  return parseHexColor(explicit) ??
      ((secondsLeft != null && secondsLeft <= 3)
          ? 0xFFFF3B30
          : module.timerColorValue ?? (rest ? 0xFF0047FF : 0xFFFFFFFF));
}
