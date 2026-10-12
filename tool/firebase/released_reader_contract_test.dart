// Copied by released_readers.mjs into each exact released source checkout.
// Every imported application class below is the installed version's code.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_document.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_summary_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_content.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> readCandidate(String name) => jsonDecode(
  File('${const String.fromEnvironment('CANDIDATE_CONTRACTS')}/$name')
      .readAsStringSync(),
  reviver: (_, value) => value is Map && value.containsKey('__timestampMillis')
      ? Timestamp.fromMillisecondsSinceEpoch(value['__timestampMillis'] as int)
      : value,
) as Map<String, dynamic>;

final exceptions = (jsonDecode(
  File(const String.fromEnvironment('COMPATIBILITY_EXCEPTIONS'))
      .readAsStringSync(),
) as List).map((entry) => entry['path'] as String).toSet();

void expectPreserved(Object? candidate, Object? installed, String path) {
  if (exceptions.contains(path)) {
    expect(
      candidate,
      isNot(anyOf(isA<Map>(), isA<List>())),
      reason: 'An entire object cannot be exempted: $path',
    );
    return;
  }
  if (candidate is Map) {
    expect(installed, isA<Map>(), reason: path);
    for (final key in candidate.keys) {
      if (exceptions.contains('$path/$key')) {
        expectPreserved(candidate[key], null, '$path/$key');
        continue;
      }
      expect((installed as Map).containsKey(key), isTrue, reason: path);
      expectPreserved(candidate[key], installed[key], '$path/$key');
    }
  } else if (candidate is List) {
    expect(installed, isA<List>(), reason: path);
    expect((installed as List).length, candidate.length, reason: path);
    for (var index = 0; index < candidate.length; index++) {
      expectPreserved(candidate[index], installed[index], '$path/*');
    }
  } else {
    expect(installed, candidate, reason: path);
  }
}

void main() {
  final workout = readCandidate('workout-save-current.json');
  for (final scenario in workout['scenarios'] as List) {
    test('installed reader/serializer preserves ${scenario['name']}', () {
      for (final write in scenario['writes'] as List) {
        final candidate = Map<String, dynamic>.from(write['workout'] as Map);
        final entity = WorkoutDocument.decode(candidate).toEntity();
        final installed = scenario['contentOnly'] == true
            ? WorkoutDocument.encode(WorkoutContent.fromWorkout(entity))
            : WorkoutModel.fromEntity(entity).toJson();
        expectPreserved(candidate, installed, 'workout');
        expectPreserved(
          write['summary'],
          WorkoutSummaryModel.fromEntity(summarizeWorkout(entity)).toJson(),
          'summary',
        );
      }
    });
  }
  final app = readCandidate('app-current.json');
  test('installed preferences reader/serializer retains current values', () {
    final candidate = Map<String, dynamic>.from(
      app['settings']['preferences'] as Map,
    );
    expectPreserved(
      candidate,
      WorkoutPreferences.fromJson(candidate).toJson(),
      'preferences',
    );
  });
  for (final playback in app['playback'] as List) {
    test('installed TV parses current split=${playback['split']}', () {
      final state = Map<String, dynamic>.from(playback['state'] as Map);
      final snapshot = Map<String, dynamic>.from(
        (playback['split'] == true
                ? playback['snapshot']
                : state['workoutSnapshot'])
            as Map,
      )..remove('_storedAtMs');
      final candidate =
          {...state, 'anchorServerMs': 1000, 'workoutSnapshot': snapshot}
            ..removeWhere(
              (key, _) => const {
                'schemaVersion',
                'snapshotId',
                'workoutId',
                'workoutName',
              }.contains(key),
            );
      final model = PlaybackSessionModel.fromJson(candidate);
      final entity = model.toEntity();
      final installedWorkout = WorkoutModel.fromEntity(entity.workout).toJson()
        ..['createdAt'] = entity.workout.createdAt.toIso8601String()
        ..['updatedAt'] = entity.workout.updatedAt.toIso8601String();
      expectPreserved(candidate, {
        ...model.toJson(),
        'workoutSnapshot': installedWorkout,
      }, 'playback');
    });
  }
}
