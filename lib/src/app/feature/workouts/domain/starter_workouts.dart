import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';

/// Reserved IDs survive catalog revisions. Importing again opens the user's
/// existing copy; upgrading this pack must never replace edits in that copy.
const starterWorkoutPrefix = 'starter_';
bool isStarterWorkout(String? id) =>
    id?.startsWith(starterWorkoutPrefix) == true;

enum StarterWorkout {
  basics('basics', '기본 수업', '웜업 → 메인 → 정리 운동', 0xFF526B60),
  interval('interval', '인터벌 수업', '운동 40초 · 휴식 20초 · 6세트', 0xFF526B60),
  team('team', '파트너 수업', '두 명이 번갈아 진행하는 예시', 0xFF526B60);

  const StarterWorkout(this.key, this.title, this.description, this.color);
  final String key, title, description;
  final int color;
  String get workoutId => '$starterWorkoutPrefix$key';
  // A normal, reportable class; stable per account for retry-safe conversion.
  String get ownedWorkoutId => 'class_from_$key';

  Workout createOwned(WorkoutAuthor author) {
    final source = create(author);
    return source.copyWith(id: ownedWorkoutId, name: title, folder: '');
  }

  /// Separate fixtures: the real class timing is never overwritten by the tour.
  Workout createDemo() {
    final source = create(
      const WorkoutAuthor(id: 'local-demo', displayName: '', photoUrl: null),
    );
    return source.copyWith(
      id: 'demo_$key',
      modules: source.modules
          .map(
            (m) => m.copyWith(
              workSeconds: 8,
              restSeconds: 4,
              sets: 2,
              includeFinalRest: false,
              beep: false,
            ),
          )
          .toList(),
    );
  }

  Workout create(WorkoutAuthor author) {
    WorkoutModule slide(
      String key,
      String name,
      String text,
      int seconds, {
      int sets = 1,
      int rest = 0,
      String instruction = '',
    }) => WorkoutModule.empty('starter_$key').copyWith(
      name: name,
      text: text,
      workSeconds: seconds,
      sets: sets,
      restSeconds: rest,
      includeFinalRest: false,
      designTemplate: starterIllustratedDesign,
      designHeaderLabel: title,
      designSubtitle: instruction,
      designFontWeight: 700,
      designItalic: false,
      designStyle: const SlideDesignStyle(titleWeight: 700),
      designAccentColor: color,
      designTextColor: 0xFF2B332E,
      designBackgroundColor: 0xFFFFFDF8,
      workGaugeColor: '#526B60',
      restGaugeColor: '#8B9D91',
      workTextColor: '#2B332E',
      restTextColor: '#526B60',
      appearance: const SlideAppearance(
        timerX: 0.79,
        timerY: 0.51,
        timerSize: 1.6,
        ringWidth: 18,
        setsOffsetY: 0.04,
        setsColor: 0xFF526B60,
      ),
    );
    return Workout.empty(workoutId, author).copyWith(
      name: '[예시] $title',
      folder: '시작 예시',
      brandL: '',
      brandR: '',
      modules: [
        slide('warmup', '웜업', '걷기\n어깨 돌리기\n스쿼트', 180),
        switch (this) {
          StarterWorkout.basics => slide(
            'main',
            '메인 운동',
            '스쿼트 10회\n스텝업 10회\n플랭크 20초',
            480,
            instruction: '편안한 속도로 반복해요',
          ),
          StarterWorkout.interval => slide(
            'main',
            '인터벌',
            '스쿼트\n제자리 걷기\n플랭크',
            40,
            sets: 6,
            rest: 20,
            instruction: '각 운동을 2번씩 진행해요',
          ),
          StarterWorkout.team => slide(
            'main',
            '파트너 운동',
            'A · 스쿼트 10회\nB · 제자리 걷기',
            480,
            instruction: '완료하면 역할을 바꿔요',
          ),
        },
        slide('cooldown', '정리 운동', '호흡 정리\n종아리 스트레칭\n어깨 스트레칭', 120),
      ],
    );
  }
}

abstract interface class StarterWorkoutImporter {
  /// Server transaction: create once or return the current user-owned copy.
  Future<Workout> importStarter(Workout workout);
}
