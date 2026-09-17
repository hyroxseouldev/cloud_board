import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('새 워크아웃은 모든 이벤트에 비프 1을 기본 적용하고 저장 후 복원한다', () {
    final workout = Workout.empty(
      'video-beep-workout',
      const WorkoutAuthor(id: 'owner', displayName: '매장', photoUrl: null),
    );
    expect(workout.soundTheme, WorkoutSoundTheme.videoBeep);
    final theme = soundsForTheme(workout.soundTheme);
    expect(theme.countdown, workout.countdownSound);
    expect(theme.workStart, workout.workStartSound);
    expect(theme.restStart, workout.restStartSound);
    expect(theme.workoutEnd, workout.workoutEndSound);
    final restored = WorkoutModel.fromJson(
      WorkoutModel.fromEntity(workout).toJson(),
    ).toEntity();
    expect(restored.countdownSound, WorkoutSound.videoBeep);
    expect(restored.workStartSound, WorkoutSound.videoBeep);
    expect(restored.restStartSound, WorkoutSound.videoBeep);
    expect(restored.workoutEndSound, WorkoutSound.videoBeep);
  });

  test('비프 1 음원은 번들에 포함된 짧은 PCM WAV다', () async {
    final bytes = await rootBundle.load('assets/sounds/video_beep.wav');
    final data = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    expect(String.fromCharCodes(data.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(data.sublist(8, 12)), 'WAVE');
    expect(bytes.getUint16(20, Endian.little), 1);
    expect(bytes.getUint16(34, Endian.little), 16);
    final duration =
        bytes.getUint32(40, Endian.little) / bytes.getUint32(28, Endian.little);
    expect(duration, inExclusiveRange(0.4, 0.8));
  });

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

  test('기존 테마는 이벤트마다 구분되는 소리를 유지한다', () {
    for (final theme in WorkoutSoundTheme.values.where(
      (value) =>
          value != WorkoutSoundTheme.custom &&
          value != WorkoutSoundTheme.videoBeep,
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
