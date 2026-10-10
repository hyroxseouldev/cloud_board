import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';

/// Reserved IDs survive catalog revisions. Importing again opens the user's
/// existing copy; upgrading this pack must never replace edits in that copy.
const starterWorkoutPrefix = 'starter_';
bool isStarterWorkout(String? id) =>
    id?.startsWith(starterWorkoutPrefix) == true;

enum StarterWorkout {
  basics('basics', '기본 수업', '웜업 → 메인 → 정리 운동', 0xFF2563EB),
  interval('interval', '인터벌 수업', '운동 40초 · 휴식 20초 · 6세트', 0xFF087F70),
  team('team', '파트너 수업', '두 명이 번갈아 진행하는 예시', 0xFFC55B18);

  const StarterWorkout(this.key, this.title, this.description, this.color);
  final String key, title, description;
  final int color;
  String get workoutId => '$starterWorkoutPrefix$key';
  // A normal, reportable class; stable per account for retry-safe conversion.
  String get ownedWorkoutId => 'class_from_$key';

  Workout createOwned(WorkoutAuthor author) {
    final source = create(author);
    return source.copyWith(
      id: ownedWorkoutId,
      name: title,
      folder: '',
      modules: source.modules
          .map(
            (m) => m.copyWith(
              designHeaderLabel: 'DAILY TRAINING',
              designSubtitle: '',
            ),
          )
          .toList(),
    );
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
    }) => WorkoutModule.empty('starter_$key').copyWith(
      name: name,
      text: text,
      workSeconds: seconds,
      sets: sets,
      restSeconds: rest,
      includeFinalRest: false,
      designTemplate: 'studio-v1-numbered',
      designHeaderLabel: 'STARTER CLASS',
      designSubtitle: '예시 · 자유롭게 수정하세요',
      designStyle: const SlideDesignStyle(),
      designAccentColor: color,
      designTextColor: 0xFF202028,
      appearance: const SlideAppearance(setsColor: 0xFF202028),
    );
    return Workout.empty(workoutId, author).copyWith(
      name: '[예시] $title',
      folder: '시작 예시',
      brandL: '',
      brandR: '',
      modules: [
        slide('warmup', 'WARM UP', '가볍게 걷기\n어깨 돌리기\n맨몸 스쿼트', 180),
        switch (this) {
          StarterWorkout.basics => slide(
            'main',
            'MAIN WORKOUT',
            '스쿼트 10회\n스텝업 10회\n플랭크 20초\n편안한 속도로 반복',
            480,
          ),
          StarterWorkout.interval => slide(
            'main',
            'INTERVAL',
            '스쿼트\n제자리 걷기\n플랭크\n각 운동을 2번씩 진행',
            40,
            sets: 6,
            rest: 20,
          ),
          StarterWorkout.team => slide(
            'main',
            'PARTNER WORKOUT',
            'A · 스쿼트 10회\nB · 제자리 걷기\n완료하면 역할 바꾸기',
            480,
          ),
        },
        slide('cooldown', 'COOL DOWN', '호흡 정리\n종아리 스트레칭\n어깨 스트레칭', 120),
      ],
    );
  }
}

abstract interface class StarterWorkoutImporter {
  /// Server transaction: create once or return the current user-owned copy.
  Future<Workout> importStarter(Workout workout);
}
