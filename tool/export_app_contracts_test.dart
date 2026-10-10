import 'dart:convert';
import 'dart:io';

import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_start_documents.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_preferences_document.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
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
    final output = File('build/contracts/app-current.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        'format': 1,
        'settings': workoutPreferencesDocument(const WorkoutPreferences(revision: 1), contentOnly: false, serverTimestamp: {'__serverTimestamp': true}),
        'playback': playback,
      })}\n',
    );
  });
}
