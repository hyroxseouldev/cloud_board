import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/preparation_lesson_content.dart';

import 'support/main_navigation_fixture.dart';

void main() {
  final base = WorkoutModule.empty('module')
      .copyWith(workSeconds: 40, restSeconds: 20, sets: 3);
  final workout = navigationWorkouts().first;
  test('summary preserves fixed, capped and mixed open duration semantics', () {
    final capped = createContinuousTimer(
      base,
      mode: WorkoutTimerMode.forTime,
      seconds: 300,
      direction: TimerDirection.up,
    );
    final open = capped.copyWith(workSeconds: 0);
    expect(preparationDurationText(workout.copyWith(modules: [base])), '3:00');
    expect(
      preparationDurationText(workout.copyWith(modules: [capped])),
      '최대 5:00',
    );
    expect(
      preparationDurationText(workout.copyWith(modules: [open])),
      '제한시간 없음',
    );
    expect(
      preparationDurationText(workout.copyWith(modules: [base, open])),
      '3:00 + 제한시간 없음',
    );
    expect(
      preparationDurationText(workout.copyWith(modules: [base, capped, open])),
      '최대 8:00 + 제한시간 없음',
    );
    expect(preparationModuleDetails(open), ['경과 시간을 표시해요.']);
    expect(
      preparationTimerKinds(workout.copyWith(modules: [base, capped, open])),
      '사용자 지정 · For Time',
    );
  });
  test(
    'composition respects blocks, final rest, rest-only and legacy rounds',
    () {
      expect(preparationModuleDetails(base), ['3세트 · 운동 0:40 · 휴식 0:20']);
      expect(
        preparationModuleDetails(
          base.copyWith(
            includeFinalRest: false,
            rounds: 2,
            roundRestSeconds: 60,
            includeFinalRoundRest: false,
          ),
        ),
        [
          '3세트 · 운동 0:40 · 휴식 0:20',
          '마지막 세트 휴식 제외',
          '2라운드 · 라운드 휴식 1:00 · 마지막 라운드 휴식 제외',
        ],
      );
      expect(
        preparationModuleDetails(base.copyWith(timingVersion: 1, rounds: 2)),
        ['3세트 · 운동 0:40 · 휴식 0:20'],
      );
      expect(
        preparationModuleDetails(
          base.copyWith(workSeconds: 0, includeFinalRest: false),
        ),
        ['3세트 · 휴식 0:20'],
      );
      expect(
        preparationModuleDetails(
          base.copyWith(
            intervalBlocks: const [
              WorkoutIntervalBlock(
                id: 'a',
                workSeconds: 30,
                restSeconds: 10,
                sets: 2,
              ),
              WorkoutIntervalBlock(
                id: 'b',
                workSeconds: 60,
                restSeconds: 0,
                sets: 1,
              ),
            ],
          ),
        ),
        ['1번 블록: 2세트 · 운동 0:30 · 휴식 0:10', '2번 블록: 1세트 · 운동 1:00'],
      );
    },
  );
}
