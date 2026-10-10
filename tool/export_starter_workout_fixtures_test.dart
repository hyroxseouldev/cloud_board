import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_save_documents.dart';

void main() {
  test('export current starter pack through production serializer', () {
    final fixtures = [
      for (final contentOnly in [false, true])
        for (final owned in [false, true])
          for (final starter in StarterWorkout.values)
            () {
              const author = WorkoutAuthor(
                id: 'owner',
                displayName: 'Coach',
                photoUrl: null,
              );
              final workout = owned
                  ? starter.createOwned(author)
                  : starter.create(author);
              final documents = WorkoutSaveDocuments(
                WorkoutModel.fromEntity(workout),
                contentOnly: contentOnly,
              );
              return {
                'contentOnly': contentOnly,
                'workout': documents.workout,
                'summary': documents.summary,
              };
            }(),
    ];
    final output = File('build/contracts/starter-workouts.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      JsonEncoder.withIndent('  ', (value) {
        if (value is Timestamp) {
          return {'__timestampMillis': value.millisecondsSinceEpoch};
        }
        throw UnsupportedError('Unexpected value ${value.runtimeType}');
      }).convert(fixtures),
    );
  });
}
