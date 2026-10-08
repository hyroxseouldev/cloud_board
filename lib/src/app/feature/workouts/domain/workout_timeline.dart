import 'dart:math' as math;

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';

// Shared with functions/src/workout-timing.js. Keep the fixture tests in sync.
const maxTimingSeconds = 59999;
const maxTimingRepeats = 999;
const maxTimingBlocks = 100;
const maxModuleSteps = 10000;

bool hasRoundTiming(WorkoutModule module) =>
    module.rounds > 1 || module.roundRestSeconds > 0;

bool needsExtendedTiming(WorkoutModule module) =>
    hasRoundTiming(module) ||
    (module.timingVersion >= 2 &&
        effectiveIntervalBlocks(module).any((b) => b.workSeconds == 0));

bool blockHasRest(WorkoutModule module, WorkoutIntervalBlock block, int set) =>
    block.restSeconds > 0 &&
    ((module.timingVersion >= 2 && block.workSeconds == 0) ||
        module.includeFinalRest ||
        set < block.sets);

String? timingValidationError(WorkoutModule module) {
  final blocks = effectiveIntervalBlocks(module);
  if (module.timingVersion != 1 && module.timingVersion != 2) {
    return '이 타이머를 사용하려면 앱을 업데이트해 주세요.';
  }
  if (module.timingVersion == 1 && hasRoundTiming(module)) {
    return '타이머 편집에서 라운드 설정을 다시 적용해 주세요.';
  }
  if (module.rounds < 1 || module.rounds > maxTimingRepeats) {
    return '라운드 반복은 1~999회로 설정해 주세요.';
  }
  if (module.roundRestSeconds < 0 ||
      module.roundRestSeconds > maxTimingSeconds) {
    return '라운드 휴식은 0초~999분 59초로 설정해 주세요.';
  }
  if (blocks.length > maxTimingBlocks) return '블록은 100개까지 만들 수 있습니다.';
  var perRoundSteps = 0;
  for (final b in blocks) {
    if (b.workSeconds < 0 ||
        b.restSeconds < 0 ||
        b.workSeconds > maxTimingSeconds ||
        b.restSeconds > maxTimingSeconds) {
      return '운동·휴식 시간은 0초~999분 59초로 설정해 주세요.';
    }
    if ((b.workSeconds == 0 && b.restSeconds == 0) ||
        (module.timingVersion == 1 && b.workSeconds == 0)) {
      return '운동 또는 휴식 시간을 1초 이상 설정해 주세요.';
    }
    if (b.sets < 1 || b.sets > maxTimingRepeats) {
      return '블록 반복은 1~999회로 설정해 주세요.';
    }
    perRoundSteps += b.workSeconds > 0 ? b.sets : 0;
    if (b.restSeconds > 0) {
      perRoundSteps += blockHasRest(module, b, b.sets) ? b.sets : b.sets - 1;
    }
  }
  final rests = module.roundRestSeconds == 0
      ? 0
      : module.rounds - (module.includeFinalRoundRest ? 0 : 1);
  if (perRoundSteps * module.rounds + rests > maxModuleSteps) {
    return '재생 구간이 10,000개를 넘습니다. 블록이나 반복 수를 줄여 주세요.';
  }
  return null;
}

class WorkoutPhase {
  const WorkoutPhase({
    required this.blockIndex,
    required this.set,
    required this.totalSets,
    required this.round,
    required this.totalRounds,
    required this.interval,
    required this.totalIntervals,
    required this.seconds,
    required this.isRest,
    this.isRoundRest = false,
  });
  final int blockIndex, set, totalSets, round, totalRounds;
  final int interval, totalIntervals, seconds;
  final bool isRest, isRoundRest;

  String get positionLabel =>
      '라운드 $round/$totalRounds · '
      '${isRest ? '휴식' : '구간 $interval/$totalIntervals'}';
}

String? workoutPhaseLabel(WorkoutModule module, WorkoutPhase phase) {
  if (hasRoundTiming(module)) return phase.positionLabel;
  if (module.timingVersion >= 2 &&
      phase.isRest &&
      effectiveIntervalBlocks(module)[phase.blockIndex].workSeconds == 0) {
    return '휴식 ${phase.set}/${phase.totalSets}';
  }
  return null;
}

final _timelines = Expando<List<WorkoutPhase>>('immutable workout timelines');

/// The only Dart expansion rule. Immutable entities make this cache safe for
/// preview ticks and seeking. Old snapshots retain their historical steps.
List<WorkoutPhase> workoutModuleTimeline(WorkoutModule module) =>
    _timelines[module] ??= _expand(module);

List<WorkoutPhase> _expand(WorkoutModule module) {
  if (timingValidationError(module) != null) {
    // Legacy sessions may contain zero work/sets; preserve their old indexing.
    if (module.timingVersion != 1) return const [];
    final blocks = effectiveIntervalBlocks(module);
    if (blocks.length > maxTimingBlocks ||
        blocks.any(
          (b) =>
              b.sets > maxTimingRepeats ||
              b.workSeconds < 0 ||
              b.restSeconds < 0,
        ) ||
        blocks.fold<int>(0, (sum, b) => sum + math.max(1, b.sets) * 2) >
            maxModuleSteps) {
      return const [];
    }
  }
  final blocks = effectiveIntervalBlocks(module);
  final rounds = module.timingVersion == 1 ? 1 : module.rounds;
  final totalIntervals = blocks.fold<int>(
    0,
    (sum, b) => sum + math.max(1, b.sets),
  );
  final result = <WorkoutPhase>[];
  for (var round = 1; round <= rounds; round++) {
    var interval = 0;
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final sets = math.max(1, b.sets);
      for (var set = 1; set <= sets; set++) {
        interval++;
        void add(int seconds, bool rest) {
          if (seconds <= 0) return;
          result.add(
            WorkoutPhase(
              blockIndex: i,
              set: set,
              totalSets: sets,
              round: round,
              totalRounds: rounds,
              interval: interval,
              totalIntervals: totalIntervals,
              seconds: seconds,
              isRest: rest,
            ),
          );
        }

        add(
          module.timingVersion == 1
              ? math.max(1, b.workSeconds)
              : b.workSeconds,
          false,
        );
        if (blockHasRest(module, b, set)) add(b.restSeconds, true);
      }
    }
    if (module.timingVersion >= 2 &&
        module.roundRestSeconds > 0 &&
        (round < rounds || module.includeFinalRoundRest)) {
      result.add(
        WorkoutPhase(
          blockIndex: blocks.length - 1,
          set: blocks.last.sets,
          totalSets: blocks.last.sets,
          round: round,
          totalRounds: rounds,
          interval: totalIntervals,
          totalIntervals: totalIntervals,
          seconds: module.roundRestSeconds,
          isRest: true,
          isRoundRest: true,
        ),
      );
    }
  }
  return List.unmodifiable(result);
}

int workoutModuleWorkSeconds(WorkoutModule module) =>
    workoutModuleTimeline(module)
        .where((p) => !p.isRest)
        .fold(0, (sum, p) => sum + p.seconds);

/// A fixed-spacing editor is a view of the timing model, never a second source.
typedef EmomConfiguration = ({
  int seconds,
  int intervals,
  int rounds,
  int restSeconds,
  bool includeFinalRest,
});

EmomConfiguration? emomConfiguration(WorkoutModule module) {
  final blocks = effectiveIntervalBlocks(module);
  final first = blocks.first;
  final count = blocks.fold<int>(0, (sum, b) => sum + b.sets);
  if (first.workSeconds <= 0 ||
      count > maxTimingBlocks ||
      blocks.any(
        (b) => b.workSeconds != first.workSeconds || b.restSeconds != 0,
      ) ||
      timingValidationError(module) != null) {
    return null;
  }
  return (
    seconds: first.workSeconds,
    intervals: count,
    rounds: module.rounds,
    restSeconds: module.roundRestSeconds,
    includeFinalRest: module.includeFinalRoundRest,
  );
}

WorkoutModule createEmom(WorkoutModule module, EmomConfiguration config) {
  if (config.intervals < 1 || config.intervals > maxTimingBlocks) {
    throw const FormatException('라운드당 구간 수는 1~100개로 설정해 주세요.');
  }
  final result =
      withIntervalBlocks(module, [
        for (var i = 0; i < config.intervals; i++)
          WorkoutIntervalBlock(
            id: '${module.id}-emom-${i + 1}',
            workSeconds: config.seconds,
            restSeconds: 0,
            sets: 1,
          ),
      ]).copyWith(
        rounds: config.rounds,
        roundRestSeconds: config.restSeconds,
        includeFinalRoundRest: config.includeFinalRest,
      );
  final error = timingValidationError(result);
  if (config.seconds <= 0 || error != null) {
    throw FormatException(error ?? '구간 시간을 1초 이상 설정해 주세요.');
  }
  return result;
}
