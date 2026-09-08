enum WorkoutSound {
  silent('무음'),
  classicBeep('클래식 비프'),
  sharpBeep('선명한 비프'),
  lowPulse('낮은 펄스'),
  boxingBell('복싱 벨'),
  softBell('부드러운 벨'),
  doubleBeep('더블 비프'),
  longFinish('긴 종료음');

  const WorkoutSound(this.label);

  final String label;

  static WorkoutSound fromName(
    String? name, {
    WorkoutSound fallback = WorkoutSound.classicBeep,
  }) => WorkoutSound.values.firstWhere(
    (value) => value.name == name,
    orElse: () => fallback,
  );
}

enum WorkoutSoundTheme {
  classic('클래식 비프', '익숙하고 또렷한 전자 비프음'),
  boxing('복싱 짐', '강한 벨로 구간을 확실하게 구분'),
  studio('부드러운 스튜디오', '부담이 적은 차분한 알림음'),
  custom('직접 설정', '각 상황의 소리를 개별 선택');

  const WorkoutSoundTheme(this.label, this.description);

  final String label;
  final String description;

  static WorkoutSoundTheme fromName(String? name) =>
      WorkoutSoundTheme.values.firstWhere(
        (value) => value.name == name,
        orElse: () => WorkoutSoundTheme.classic,
      );
}

class WorkoutSoundSelection {
  const WorkoutSoundSelection({
    required this.countdown,
    required this.workStart,
    required this.restStart,
    required this.workoutEnd,
  });

  final WorkoutSound countdown;
  final WorkoutSound workStart;
  final WorkoutSound restStart;
  final WorkoutSound workoutEnd;
}

WorkoutSoundSelection soundsForTheme(WorkoutSoundTheme theme) =>
    switch (theme) {
      WorkoutSoundTheme.classic => const WorkoutSoundSelection(
        countdown: WorkoutSound.classicBeep,
        workStart: WorkoutSound.sharpBeep,
        restStart: WorkoutSound.lowPulse,
        workoutEnd: WorkoutSound.longFinish,
      ),
      WorkoutSoundTheme.boxing => const WorkoutSoundSelection(
        countdown: WorkoutSound.sharpBeep,
        workStart: WorkoutSound.boxingBell,
        restStart: WorkoutSound.doubleBeep,
        workoutEnd: WorkoutSound.longFinish,
      ),
      WorkoutSoundTheme.studio => const WorkoutSoundSelection(
        countdown: WorkoutSound.softBell,
        workStart: WorkoutSound.doubleBeep,
        restStart: WorkoutSound.lowPulse,
        workoutEnd: WorkoutSound.softBell,
      ),
      WorkoutSoundTheme.custom => const WorkoutSoundSelection(
        countdown: WorkoutSound.classicBeep,
        workStart: WorkoutSound.sharpBeep,
        restStart: WorkoutSound.softBell,
        workoutEnd: WorkoutSound.longFinish,
      ),
    };
