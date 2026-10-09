import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';

bool _hasEmomShape(List<WorkoutIntervalBlock> blocks) =>
    blocks.first.workSeconds > 0 &&
    blocks.every(
      (b) =>
          b.workSeconds == blocks.first.workSeconds &&
          b.restSeconds == 0 &&
          b.sets == 1,
    );

/// A presentation of the complete saved configuration, never a migration.
WorkoutTimerMode timerInputMode(WorkoutModule module) {
  if (isContinuousTimer(module)) return module.timerMode;
  final blocks = effectiveIntervalBlocks(module);
  if (module.timerMode == WorkoutTimerMode.emom && _hasEmomShape(blocks)) {
    return WorkoutTimerMode.emom;
  }
  if (blocks.length == 1 &&
      blocks.first.workSeconds > 0 &&
      module.rounds == 1 &&
      module.roundRestSeconds == 0) {
    return module.timerMode == WorkoutTimerMode.tabata &&
            blocks.first.workSeconds == 20 &&
            blocks.first.restSeconds == 10 &&
            blocks.first.sets == 8 &&
            module.includeFinalRest
        ? WorkoutTimerMode.tabata
        : WorkoutTimerMode.interval;
  }
  return WorkoutTimerMode.custom;
}

String timerEditorLabel(WorkoutModule module) =>
    timerModeLabel(timerInputMode(module));

String timerModeDescription(WorkoutTimerMode mode) => switch (mode) {
  WorkoutTimerMode.emom => '일정한 간격마다 다음 구간을 시작해요',
  WorkoutTimerMode.amrap => '정해진 시간 동안 최대한 많은 반복을 수행해요',
  WorkoutTimerMode.forTime => '운동을 마칠 때까지 경과 시간을 확인해요',
  WorkoutTimerMode.tabata => '운동 20초와 휴식 10초를 8회 반복해요',
  WorkoutTimerMode.interval => '운동과 휴식을 번갈아 진행해요',
  WorkoutTimerMode.custom => '구간과 휴식을 원하는 순서로 구성해요',
};

/// Preserve a mode only while every part remains representable by its form.
WorkoutModule editTimerBlocks(
  WorkoutModule source,
  List<WorkoutIntervalBlock> blocks,
) {
  if (blocks.isEmpty) return source;
  final candidate = withIntervalBlocks(source, blocks).copyWith(
    timingVersion: source.timingVersion.clamp(2, 3),
    timerDirection: source.timerDirection,
  );
  if (source.timerMode == WorkoutTimerMode.emom && _hasEmomShape(blocks)) {
    return candidate.copyWith(timingVersion: 3, timerMode: source.timerMode);
  }
  if ((source.timerMode == WorkoutTimerMode.interval ||
          source.timerMode == WorkoutTimerMode.tabata) &&
      timerInputMode(candidate) == WorkoutTimerMode.interval) {
    final first = blocks.first;
    return candidate.copyWith(
      timingVersion: 3,
      timerMode:
          source.timerMode == WorkoutTimerMode.tabata &&
              first.workSeconds == 20 &&
              first.restSeconds == 10 &&
              first.sets == 8 &&
              candidate.includeFinalRest
          ? WorkoutTimerMode.tabata
          : WorkoutTimerMode.interval,
    );
  }
  return candidate;
}

WorkoutModule editEmom(WorkoutModule source, EmomConfiguration config) {
  final old = effectiveIntervalBlocks(source);
  final usedIds = old.map((b) => b.id).toSet();
  String idFor(int index) {
    if (index < old.length) return old[index].id;
    var suffix = index + 1;
    while (!usedIds.add('${source.id}-emom-$suffix')) {
      suffix++;
    }
    return '${source.id}-emom-$suffix';
  }

  return source.copyWith(
    timingVersion: 3,
    timerMode: WorkoutTimerMode.emom,
    timerDirection: TimerDirection.down,
    workSeconds: config.seconds,
    restSeconds: 0,
    sets: 1,
    intervalBlocks: [
      for (var i = 0; i < config.intervals; i++)
        WorkoutIntervalBlock(
          id: idFor(i),
          workSeconds: config.seconds,
          restSeconds: 0,
          sets: 1,
        ),
    ],
    rounds: config.rounds,
    roundRestSeconds: config.restSeconds,
    includeFinalRoundRest: config.includeFinalRest,
  );
}

WorkoutModule timerModeCandidate(WorkoutModule source, WorkoutTimerMode mode) {
  if (mode == WorkoutTimerMode.custom || timerInputMode(source) == mode) {
    return source;
  }
  final existingEmom = emomConfiguration(source);
  if (mode == WorkoutTimerMode.emom &&
      !isContinuousTimer(source) &&
      existingEmom != null &&
      effectiveIntervalBlocks(source).every((b) => b.sets == 1)) {
    return editEmom(source, existingEmom);
  }
  return switch (mode) {
    WorkoutTimerMode.amrap => createContinuousTimer(
      source,
      mode: mode,
      seconds: 600,
      direction: TimerDirection.down,
    ),
    WorkoutTimerMode.forTime => createContinuousTimer(
      source,
      mode: mode,
      seconds: 0,
      direction: TimerDirection.up,
    ),
    WorkoutTimerMode.emom => editEmom(source, (
      seconds: 60,
      intervals: 1,
      rounds: 10,
      restSeconds: 0,
      includeFinalRest: true,
    )),
    WorkoutTimerMode.tabata => createIntervalTimer(
      source,
      workSeconds: 20,
      restSeconds: 10,
      repeats: 8,
      includeFinalRest: true,
      tabata: true,
    ),
    WorkoutTimerMode.interval => createIntervalTimer(
      source,
      workSeconds: 45,
      restSeconds: 15,
      repeats: 10,
      includeFinalRest: true,
    ),
    WorkoutTimerMode.custom => source,
  };
}

String timerComposition(WorkoutModule module) {
  if (isContinuousTimer(module)) {
    if (isOpenEndedTimer(module)) return '운동 완료를 누를 때까지 진행';
    return '${formatSlideTime(module.workSeconds)} 동안 연속 운동';
  }
  final blocks = effectiveIntervalBlocks(module);
  if (timerInputMode(module) == WorkoutTimerMode.emom) {
    return '${formatSlideTime(blocks.first.workSeconds)} 간격 · ${blocks.length}구간';
  }
  if (blocks.length == 1) {
    final b = blocks.first;
    if (b.workSeconds == 0) return '휴식 ${formatSlideTime(b.restSeconds)}';
    return '운동 ${formatSlideTime(b.workSeconds)}'
        '${b.restSeconds > 0 ? ' → 휴식 ${formatSlideTime(b.restSeconds)}' : ''}';
  }
  final workCount = blocks.where((b) => b.workSeconds > 0).length;
  final restCount = blocks.length - workCount;
  return [
    if (workCount > 0) '운동 $workCount구간',
    if (restCount > 0) '휴식만 $restCount구간',
  ].join(' · ');
}

String timerRepeatDescription(WorkoutModule module) {
  if (module.timerMode == WorkoutTimerMode.forTime) {
    return '완료 후 다음 슬라이드를 직접 선택';
  }
  if (module.timerMode == WorkoutTimerMode.amrap) return '시간이 끝나면 다음 슬라이드로 이동';
  if (hasRoundTiming(module)) {
    return '전체 ${module.rounds}라운드'
        '${module.roundRestSeconds > 0 ? ' · 라운드 휴식 ${formatSlideTime(module.roundRestSeconds)}' : ''}';
  }
  final blocks = effectiveIntervalBlocks(module);
  return blocks.length == 1
      ? '위 순서를 ${blocks.first.sets}회 반복'
      : '구간별 반복 후 다음 구간으로 이동';
}

String? timerRestDescription(WorkoutModule module) {
  if (isContinuousTimer(module)) return null;
  if (module.roundRestSeconds > 0) {
    return module.includeFinalRoundRest ? '마지막 라운드 휴식 포함' : '마지막 라운드 휴식 제외';
  }
  if (!effectiveIntervalBlocks(module)
      .any((b) => b.workSeconds > 0 && b.restSeconds > 0)) {
    return null;
  }
  return module.includeFinalRest ? '마지막 휴식 포함' : '마지막 자동 휴식 제외';
}
