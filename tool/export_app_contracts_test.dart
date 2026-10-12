import 'dart:convert';
import 'dart:io';

import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_start_documents.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_preferences_document.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export actual settings and both playback wire protocols', () {
    final workout = Workout.empty(
      'contract-workout',
      const WorkoutAuthor(id: 'owner', displayName: 'Test', photoUrl: null),
    ).copyWith(name: 'Contract', modules: [WorkoutModule.empty('slide')]);
    final playback = [
      for (final split in [false, true])
        () {
          final model = PlaybackSessionModel.fromWorkout(
            id: split ? 'session-v2' : 'session-v1',
            ownerId: 'owner',
            zoneId: 'main',
            targetDeviceIds: ['tv'],
            workout: workout,
            stepIndex: 0,
            durationMs: 60000,
            deviceId: 'phone',
          );
          final documents = PlaybackStartDocuments(model, split: split);
          expect(documents.state.containsKey('workoutSnapshot'), !split);
          return {
            'split': split,
            'state': documents.state,
            'snapshot': documents.snapshot,
          };
        }(),
    ];
    // Behavioral inputs must come from the same validated timer factories as
    // the editor. The save/rules fixtures exercise DTO fields and are not all
    // playable timer combinations (for example For Time requires timing v3).
    final behavior = [
      for (final kind in ['fixed', 'maximum', 'open'])
        () {
          final module = kind == 'fixed'
              ? WorkoutModule.empty('behavior-slide')
              : createContinuousTimer(
                  WorkoutModule.empty('behavior-slide'),
                  mode: WorkoutTimerMode.forTime,
                  seconds: kind == 'open' ? 0 : 60,
                  direction: TimerDirection.up,
                );
          expect(timingValidationError(module), isNull);
          final model = PlaybackSessionModel.fromWorkout(
            id: 'behavior-$kind',
            ownerId: 'owner',
            zoneId: 'main',
            targetDeviceIds: ['tv'],
            workout: workout.copyWith(modules: [module]),
            stepIndex: 0,
            durationMs: kind == 'open' ? 0 : 60000,
            deviceId: 'phone',
          );
          return {
            'name': kind,
            'state': {
              ...model.toJson(),
              'anchorServerMs': 1000,
              'startDelayMs': 0,
            },
            'serverNowMs': 62000,
            'expectedDurationsMs': [kind == 'open' ? 0 : 60000],
            'expectedIndex': kind == 'fixed' ? 1 : 0,
            'expectedRemainingMs': kind == 'open' ? 61000 : 0,
          };
        }(),
    ];
    final output = File('build/contracts/app-current.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        'format': 1,
        'settings': workoutPreferencesDocument(const WorkoutPreferences(revision: 1), contentOnly: false, serverTimestamp: {'__serverTimestamp': true}),
        'playback': playback,
        'behavior': behavior,
      })}\n',
    );
  });
}
