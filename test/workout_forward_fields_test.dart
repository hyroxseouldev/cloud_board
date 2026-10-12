import 'package:cloud_board/src/app/feature/workouts/data/models/workout_document.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_save_documents.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'older DTO edit preserves additive fields and matches nested lists by ID',
    () {
      final original =
          Workout.empty(
            'workout',
            const WorkoutAuthor(
              id: 'owner',
              displayName: 'Coach',
              photoUrl: null,
            ),
          ).copyWith(
            modules: [
              WorkoutModule.empty('a'),
              WorkoutModule.empty('b'),
              WorkoutModule.empty('deleted'),
            ],
          );
      final previous = WorkoutSaveDocuments(
        WorkoutModel.fromEntity(original),
        contentOnly: false,
      ).workout;
      previous['futureMetadata'] = {'recording': 'keep'};
      (previous['author'] as Map)['futureBadge'] = 'keep';
      final modules = previous['modules'] as List;
      for (final module in modules) {
        (module as Map)['futureOverlay'] = {'owner': module['id']};
        (module['appearance'] as Map)['futureContrast'] = true;
      }
      final loaded = WorkoutDocument.decode(previous).toEntity();
      final edited = loaded.copyWith(
        name: 'Edited',
        modules: [
          loaded.modules[1].copyWith(name: 'B edited'),
          loaded.modules[0],
          WorkoutModule.empty('new'),
        ],
      );
      final saved = WorkoutSaveDocuments(
        WorkoutModel.fromEntity(edited),
        contentOnly: false,
        previous: previous,
      ).workout;
      expect(saved['name'], 'Edited');
      expect(saved['futureMetadata'], {'recording': 'keep'});
      expect((saved['author'] as Map)['futureBadge'], 'keep');
      final result = saved['modules'] as List;
      expect(result.map((m) => m['id']), ['b', 'a', 'new']);
      expect(result[0]['futureOverlay'], {'owner': 'b'});
      expect(result[1]['futureOverlay'], {'owner': 'a'});
      expect(result[0]['appearance']['futureContrast'], true);
      expect((result[2] as Map).containsKey('futureOverlay'), false);
    },
  );

  test('known nullable-field removal is not undone by preservation', () {
    final original =
        Workout.empty(
          'workout',
          const WorkoutAuthor(
            id: 'owner',
            displayName: 'Coach',
            photoUrl: null,
          ),
        ).copyWith(
          modules: [
            WorkoutModule.empty('a')
                .copyWith(designTemplate: 'plain', designFingerprint: 'known'),
          ],
        );
    final previous = WorkoutModel.fromEntity(original).toJson();
    final edited = original.copyWith(
      modules: [
        original.modules.single.copyWith(
          designTemplate: null,
          designFingerprint: null,
        ),
      ],
    );
    final saved = WorkoutSaveDocuments(
      WorkoutModel.fromEntity(edited),
      contentOnly: true,
      previous: previous,
    ).workout;
    final module = (saved['modules'] as List).single as Map;
    expect(module.containsKey('designTemplate'), false);
    expect(module.containsKey('designFingerprint'), false);
    expect(WorkoutDocument.legacySettingKeys.any(saved.containsKey), false);
  });
}
