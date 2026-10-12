import 'dart:convert';
import 'dart:io';

import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_document.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_preferences_document.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_save_documents.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture(String path) => jsonDecode(
  File(path).readAsStringSync(),
  reviver: (_, value) => value is Map && value.containsKey('__timestampMillis')
      ? Timestamp.fromMillisecondsSinceEpoch(value['__timestampMillis'] as int)
      : value,
) as Map<String, dynamic>;

// New optional fields may appear, but an edit must retain every field the
// installed client originally wrote, including nested timer/appearance values.
void _expectPreserved(Object? before, Object? after, String path) {
  if (before is Map) {
    expect(after, isA<Map>(), reason: path);
    for (final key in before.keys) {
      expect((after as Map).containsKey(key), isTrue, reason: '$path/$key');
      _expectPreserved(before[key], after[key], '$path/$key');
    }
  } else if (before is List) {
    expect(after, isA<List>(), reason: path);
    expect((after as List).length, before.length, reason: path);
    for (var index = 0; index < before.length; index++) {
      _expectPreserved(before[index], after[index], '$path/$index');
    }
  } else {
    expect(after, before, reason: path);
  }
}

void main() {
  final clients = _fixture('tool/firebase/supported-clients.json')['clients'];
  for (final client in clients as List) {
    final fixture = _fixture(client['file'] as String);
    for (final scenario in fixture['scenarios'] as List) {
      test(
        '${client['client']} ${scenario['name']}: read and edit keeps released data',
        () {
          for (final write in scenario['writes'] as List) {
            final before = Map<String, dynamic>.from(write['workout'] as Map);
            final entity = WorkoutDocument.decode(before).toEntity();
            final edited = WorkoutSaveDocuments(
              WorkoutModel.fromEntity(
                entity.copyWith(name: 'Compatibility edit'),
              ),
              contentOnly: scenario['contentOnly'] as bool,
              previous: before,
            );
            _expectPreserved(
              {...before, 'name': 'Compatibility edit'},
              edited.workout,
              'workout',
            );
            _expectPreserved(
              {
                ...Map<String, dynamic>.from(write['summary'] as Map),
                'name': 'Compatibility edit',
              },
              edited.summary,
              'summary',
            );
          }
        },
      );
    }
    if (client['appContract'] == null) continue;
    final app = _fixture(client['appContract']['file'] as String);
    test('${client['client']}: preferences survive current reader/writer', () {
      final settings = Map<String, dynamic>.from(app['settings'] as Map);
      final preferences = WorkoutPreferences.fromJson({
        ...Map<String, dynamic>.from(settings['preferences'] as Map),
        'revision': settings['revision'],
      });
      _expectPreserved(
        settings,
        workoutPreferencesDocument(
          preferences,
          contentOnly: settings['contentOnly'] as bool,
          serverTimestamp: settings['updatedAt'],
        ),
        'settings',
      );
    });
    for (final playback in app['playback'] as List) {
      test(
        '${client['client']}: current TV reader accepts v${playback['split'] == true ? 2 : 1}',
        () {
          final state = Map<String, dynamic>.from(playback['state'] as Map);
          final snapshot = Map<String, dynamic>.from(
            (playback['split'] == true
                    ? playback['snapshot']
                    : state['workoutSnapshot'])
                as Map,
          );
          final model = PlaybackSessionModel.fromJson({
            ...state,
            'anchorServerMs': 1000,
            'workoutSnapshot': snapshot,
          });
          final session = model.toEntity();
          expect(session.workout.id, snapshot['id']);
          expect(session.workout.name, snapshot['name']);
          expect(
            session.workout.modules.length,
            (snapshot['modules'] as List).length,
          );
          expect(session.remainingMs, state['remainingMs']);
          expect(session.revision, state['revision']);
        },
      );
    }
  }
}
