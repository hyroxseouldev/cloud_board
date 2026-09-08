import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';

void main() {
  test('기존 워크아웃 데이터는 클래식 사운드 설정으로 불러온다', () {
    final workout = WorkoutModel.fromJson({
      'id': 'workout-1',
      'ownerId': 'owner-1',
      'author': {'id': 'owner-1', 'displayName': '테스트 매장', 'photoUrl': null},
      'name': '기존 수업',
      'folder': '',
      'brandL': 'CloudBoard',
      'brandR': '',
      'modules': <Object?>[],
      'createdAt': '2026-09-08T00:00:00.000Z',
      'updatedAt': '2026-09-08T00:00:00.000Z',
    }).toEntity();

    expect(workout.soundTheme, WorkoutSoundTheme.classic);
    expect(workout.countdownSound, WorkoutSound.classicBeep);
    expect(workout.workStartSound, WorkoutSound.sharpBeep);
    expect(workout.restStartSound, WorkoutSound.lowPulse);
    expect(workout.workoutEndSound, WorkoutSound.longFinish);
    expect(workout.soundVolume, 1);
  });

  test('세 가지 기본 테마는 이벤트마다 구분되는 소리를 제공한다', () {
    for (final theme in WorkoutSoundTheme.values.where(
      (value) => value != WorkoutSoundTheme.custom,
    )) {
      final sounds = soundsForTheme(theme);
      expect(sounds.countdown, isNot(WorkoutSound.silent));
      expect(sounds.workStart, isNot(WorkoutSound.silent));
      expect(sounds.restStart, isNot(WorkoutSound.silent));
      expect(sounds.workoutEnd, isNot(WorkoutSound.silent));
      expect(
        {
          sounds.countdown,
          sounds.workStart,
          sounds.restStart,
          sounds.workoutEnd,
        }.length,
        greaterThan(1),
      );
    }
  });
}
