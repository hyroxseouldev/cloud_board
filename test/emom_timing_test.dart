import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_rehearsal.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_interval_slider_track.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/ai_timer/domain/usecases/ai_timer_actions.dart';
import 'package:cloud_board/src/app/feature/ai_timer/domain/entities/ai_timer_result.dart';

Workout workoutWith(WorkoutModule module) => Workout.empty(
  'w',
  const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
).copyWith(countdownSeconds: 0, modules: [module]);

void main() {
  final fixtures = jsonDecode(
    File('test/fixtures/emom_timing.json').readAsStringSync(),
  ) as List;
  for (final fixture in fixtures) {
    test(
      'shared timing fixture ${fixture['name']}: storage, seek, preview and playback',
      () {
        final module = WorkoutModuleModel.fromJson({
          ...WorkoutModuleModel.fromEntity(WorkoutModule.empty('m')).toJson(),
          ...Map<String, dynamic>.from(fixture['module'] as Map),
        }).toEntity();
        final phases = workoutModuleTimeline(module);
        final expected = fixture['phases'] as List;
        expect(timingValidationError(module), isNull);
        expect(
          phases
              .map(
                (p) => {
                  'seconds': p.seconds,
                  'isRest': p.isRest,
                  'round': p.round,
                  'interval': p.interval,
                },
              )
              .toList(),
          expected,
        );
        expect(workoutModuleDuration(module), fixture['duration']);
        final restored = WorkoutModuleModel.fromJson(
          WorkoutModuleModel.fromEntity(module).toJson(),
        ).toEntity();
        expect(restored, module);
        final workout = workoutWith(restored);
        final steps = buildPlayerSteps(workout);
        final durations = playbackDurations(workout);
        expect(steps.map((s) => s.duration * 1000), durations);
        expect(durations, expected.map((p) => (p['seconds'] as int) * 1000));
        expect(
          workoutIntervalSegments(restored).map((s) => s.isRest),
          expected.map((p) => p['isRest']),
        );
        final session = PlaybackSessionModel.fromWorkout(
          id: 's',
          ownerId: 'u',
          zoneId: 'main',
          targetDeviceIds: [],
          workout: workout,
          stepIndex: 0,
          durationMs: durations.first,
          deviceId: 'c',
        ).toEntity().copyWith(anchorServerMs: 1000, startDelayMs: 0);
        var start = 0;
        for (var i = 0; i < phases.length; i++) {
          final frame = rehearsalFrame(restored, start);
          expect(frame.isRest, phases[i].isRest);
          expect(frame.remainingMs, durations[i]);
          expect(playbackPosition(session, durations, 1000 + start).index, i);
          expect(
            playbackPosition(
              session,
              durations,
              1000 + start + durations[i] - 1,
            ).index,
            i,
          );
          start += durations[i];
        }
        expect(
          playbackPosition(session, durations, 1000 + start).index,
          phases.length,
        );
        expect(rehearsalFrame(restored, start).remainingMs, 0);
      },
    );
  }

  test('invalid input and excessive expansion fail before allocation', () {
    final base = WorkoutModule.empty('m');
    for (final invalid in [
      base.copyWith(workSeconds: 0, restSeconds: 0),
      base.copyWith(workSeconds: -1),
      base.copyWith(restSeconds: -1),
      base.copyWith(sets: 0),
      base.copyWith(rounds: 0),
      base.copyWith(rounds: 1000),
      base.copyWith(roundRestSeconds: -1),
      base.copyWith(timingVersion: 99),
      base.copyWith(sets: 999, rounds: 999),
    ]) {
      expect(timingValidationError(invalid), isNotNull);
      expect(workoutModuleTimeline(invalid), isEmpty);
    }
    expect(
      () => createEmom(base, (
        seconds: 0,
        intervals: 3,
        rounds: 6,
        restSeconds: 30,
        includeFinalRest: true,
      )),
      throwsFormatException,
    );
  });

  test('EMOM configuration is derived from current timing; custom edits are preserved', () {
    final source = WorkoutModule.empty('m')
        .copyWith(name: '내용', text: '본문', imageSource: 'image');
    final emom = createEmom(source, (
      seconds: 120,
      intervals: 3,
      rounds: 6,
      restSeconds: 30,
      includeFinalRest: true,
    ));
    expect(workoutModuleDuration(emom), 2340);
    expect(emom.name, source.name);
    expect(emom.text, source.text);
    expect(emom.imageSource, source.imageSource);
    expect(emomConfiguration(emom)?.rounds, 6);
    final edited = withIntervalBlocks(emom, [
      emom.intervalBlocks.first.copyWith(workSeconds: 90),
      ...emom.intervalBlocks.skip(1),
    ]);
    expect(emomConfiguration(edited), isNull);
    expect(workoutModuleDuration(edited), 2160);
    expect(copySlideTiming(source, edited).rounds, 6);
    expect(sameSlideTiming(emom, emom.copyWith(rounds: 5)), isFalse);
    expect(canApplyAiTimer(emom, emom.copyWith(rounds: 5)), isFalse);
    expect(supportsAiTimerReplacement(emom), isFalse);
    expect(
      () => applyAiTimer(emom, workSeconds: 60, restSeconds: 0, sets: 10),
      throwsA(isA<AiTimerFailure>()),
    );
    expect(
      buildPlayerSteps(workoutWith(emom))[4].positionLabel,
      '라운드 2/6 · 구간 1/3',
    );
    expect(
      buildPlayerSteps(workoutWith(emom))[3].positionLabel,
      '라운드 1/6 · 휴식',
    );
  });

  test('legacy snapshots retain timing version and exact indexing', () {
    final old = WorkoutModule.empty('m')
        .copyWith(timingVersion: 1, workSeconds: 0, restSeconds: 30);
    expect(buildPlayerSteps(workoutWith(old)).map((p) => p.duration), [1, 30]);
    final json =
        WorkoutModuleModel.fromEntity(WorkoutModule.empty('m')).toJson()
          ..remove('timingVersion')
          ..remove('rounds')
          ..remove('roundRestSeconds')
          ..remove('includeFinalRoundRest');
    final restored = WorkoutModuleModel.fromJson(json).toEntity();
    expect(restored.timingVersion, 1);
    expect(restored.rounds, 1);
    expect(restored.roundRestSeconds, 0);
    expect(requiredTimingProtocol(workoutWith(restored)), 1);
    expect(
      requiredTimingProtocol(workoutWith(restored.copyWith(restSeconds: 30))),
      3,
    );
    expect(
      requiredTimingProtocol(
        workoutWith(
          WorkoutModule.empty('rest').copyWith(workSeconds: 0, restSeconds: 30),
        ),
      ),
      4,
    );
    expect(
      requiredTimingProtocol(
        workoutWith(WorkoutModule.empty('r').copyWith(rounds: 6)),
      ),
      4,
    );
  });
}
