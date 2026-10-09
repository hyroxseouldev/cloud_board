import 'dart:convert';
import 'dart:io';

import 'package:cloud_board/src/app/feature/workouts/data/models/workout_document.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_save_documents.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// Run before the emulator suite. Never update the supported-client fixtures as
// part of this export: those are immutable examples from the released client.
void main() {
  test('export actual app create, update and duplicate writes for rules tests', () {
    final scenarios = <Map<String, Object?>>[];
    for (final contentOnly in [false, true]) {
      for (final kind in ['fixed', 'maximum', 'open']) {
        final id = '${contentOnly ? 'content' : 'legacy'}-$kind';
        final original =
            Workout.empty(
              id,
              const WorkoutAuthor(
                id: 'owner',
                displayName: 'Coach',
                photoUrl: null,
              ),
            ).copyWith(
              name: 'Workout',
              brandL: 'Saved brand',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
              modules: [
                WorkoutModule.empty('slide').copyWith(
                  timerMode: kind == 'fixed'
                      ? WorkoutTimerMode.custom
                      : WorkoutTimerMode.forTime,
                  workSeconds: kind == 'open' ? 0 : 60,
                ),
              ],
            );
        final created = WorkoutSaveDocuments(
          WorkoutModel.fromEntity(original),
          contentOnly: contentOnly,
        );
        final edited = WorkoutSaveDocuments(
          WorkoutModel.fromEntity(
            original.copyWith(
              name: 'Edited workout',
              brandL: 'Preview only',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
            ),
          ),
          contentOnly: contentOnly,
          previous: created.workout,
        );
        final duplicated = WorkoutSaveDocuments(
          WorkoutModel.fromEntity(
            original.copyWith(
              id: '$id-copy',
              name: '${original.name} 복사',
              createdAt: DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true),
              modules: original.modules
                  .map((m) => m.copyWith(id: '${m.id}c'))
                  .toList(),
            ),
          ),
          contentOnly: contentOnly,
        );
        for (final documents in [created, edited, duplicated]) {
          expect(documents.summary['durationKind'], kind);
          expect(
            WorkoutDocument.decode(documents.workout).id,
            documents.summary['id'],
          );
        }
        if (!contentOnly) expect(edited.workout['brandL'], 'Saved brand');
        scenarios.add({
          'name': id,
          'contentOnly': contentOnly,
          'durationKind': kind,
          'writes': [
            for (final (operation, documents) in [
              ('create', created),
              ('update', edited),
              ('duplicate', duplicated),
            ])
              {
                'operation': operation,
                'workout': documents.workout,
                'summary': documents.summary,
              },
          ],
        });
      }
    }
    final output = File(
      const String.fromEnvironment(
        'WORKOUT_CONTRACT_OUTPUT',
        defaultValue: 'build/contracts/workout-save-current.json',
      ),
    );
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      '${JsonEncoder.withIndent('  ', (value) {
        if (value is Timestamp) return {'__timestampMillis': value.millisecondsSinceEpoch};
        throw UnsupportedError('Unhandled Firestore value: ${value.runtimeType}');
      }).convert({'format': 1, 'scenarios': scenarios})}\n',
    );
  });
}
