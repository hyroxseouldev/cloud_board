import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';

String timerModeLabel(WorkoutTimerMode mode) => switch (mode) {
  WorkoutTimerMode.custom => '사용자 지정',
  WorkoutTimerMode.emom => 'EMOM',
  WorkoutTimerMode.amrap => 'AMRAP',
  WorkoutTimerMode.forTime => 'For Time',
  WorkoutTimerMode.tabata => '타바타',
  WorkoutTimerMode.interval => '인터벌',
};

bool isContinuousTimer(WorkoutModule m) =>
    m.timerMode == WorkoutTimerMode.amrap ||
    m.timerMode == WorkoutTimerMode.forTime;
bool isOpenEndedTimer(WorkoutModule m) =>
    m.timerMode == WorkoutTimerMode.forTime && m.workSeconds == 0;
bool timerCountsUp(WorkoutModule m) =>
    isOpenEndedTimer(m) || m.timerDirection == TimerDirection.up;

/// Zero duration is reserved for an explicitly uncapped For Time step.
/// Its wire `remainingMs` contains elapsed time; other steps retain countdowns.
int timerElapsedMs(WorkoutModule m, int durationMs, int remainingMs) =>
    isOpenEndedTimer(m)
    ? remainingMs
    : (durationMs - remainingMs).clamp(0, durationMs);

String? timerModeValidationError(WorkoutModule m) {
  if (m.timingVersion < 1 || m.timingVersion > 3) {
    return '이 타이머를 사용하려면 앱을 업데이트해 주세요.';
  }
  if (m.timingVersion < 3 &&
      (m.timerMode != WorkoutTimerMode.custom ||
          m.timerDirection != TimerDirection.down)) {
    return '간편 만들기에서 타이머 방식을 다시 적용해 주세요.';
  }
  if (!isContinuousTimer(m)) return null;
  if (m.rounds != 1 ||
      m.roundRestSeconds != 0 ||
      m.sets != 1 ||
      m.restSeconds != 0 ||
      m.intervalBlocks.isNotEmpty) {
    return 'AMRAP과 For Time은 하나의 연속 타이머로 설정해 주세요.';
  }
  if (m.workSeconds < 0 ||
      m.workSeconds > maxTimingSeconds ||
      (m.timerMode == WorkoutTimerMode.amrap && m.workSeconds == 0)) {
    return '운동 시간을 1초~999분 59초로 설정해 주세요.';
  }
  if (isOpenEndedTimer(m) && m.timerDirection != TimerDirection.up) {
    return '제한시간 없는 For Time은 경과 시간을 표시합니다.';
  }
  return null;
}

WorkoutModule createContinuousTimer(
  WorkoutModule source, {
  required WorkoutTimerMode mode,
  required int seconds,
  required TimerDirection direction,
}) {
  if (mode != WorkoutTimerMode.amrap && mode != WorkoutTimerMode.forTime) {
    throw const FormatException('연속 타이머 방식을 선택해 주세요.');
  }
  final result = source.copyWith(
    timingVersion: 3,
    timerMode: mode,
    timerDirection: direction,
    workSeconds: seconds,
    restSeconds: 0,
    sets: 1,
    intervalBlocks: [],
    rounds: 1,
    roundRestSeconds: 0,
    includeFinalRoundRest: true,
  );
  final error = timingValidationError(result);
  if (error != null) throw FormatException(error);
  return result;
}

WorkoutModule createIntervalTimer(
  WorkoutModule source, {
  required int workSeconds,
  required int restSeconds,
  required int repeats,
  required bool includeFinalRest,
  bool tabata = false,
}) {
  final result =
      withIntervalBlocks(source, [
        WorkoutIntervalBlock(
          id: '${source.id}-interval-1',
          workSeconds: workSeconds,
          restSeconds: restSeconds,
          sets: repeats,
        ),
      ]).copyWith(
        timingVersion: 3,
        timerMode: tabata ? WorkoutTimerMode.tabata : WorkoutTimerMode.interval,
        rounds: 1,
        roundRestSeconds: 0,
        includeFinalRest: includeFinalRest,
      );
  final error = timingValidationError(result);
  if (error != null) throw FormatException(error);
  return result;
}
