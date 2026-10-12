import 'dart:math';

import 'package:cloud_board/src/app/feature/workouts/data/models/workout_summary_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_catalog_page.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

List<WorkoutSummaryModel> fixture(int count) => List.generate(
  count,
  (i) => WorkoutSummaryModel.fromEntity(
    summarizeWorkout(
      Workout.empty(
        '$i',
        const WorkoutAuthor(id: 'u', displayName: '', photoUrl: null),
      ).copyWith(updatedAt: DateTime(2026).subtract(Duration(minutes: i))),
    ),
  ),
);

void main() {
  for (final count in [24, 100, 500]) {
    test('incremental catalog maps $count unique rows only once', () {
      final models = fixture(count);
      final baseline = Stopwatch()..start();
      var beforeMappings = 0;
      var beforeSorts = 0;
      var baselineItems = <WorkoutSummary>[];
      // Pre-STA-127 algorithm: accumulated DTO pages are re-mapped and sorted
      // in the repository, then sorted again in the controller at every yield.
      for (var start = 0; start <= count; start += 24) {
        final end = min(start + 24, count);
        baselineItems = models.take(end).map((item) {
          beforeMappings++;
          return item.toEntity();
        }).toList()..sort(compareWorkoutSummaries);
        baselineItems = baselineItems.toList()..sort(compareWorkoutSummaries);
        beforeSorts += 2;
        if (end - start < 24) break;
      }
      baseline.stop();
      final after = Stopwatch()..start();
      final accumulator = WorkoutSummaryAccumulator();
      var afterMappings = 0;
      WorkoutSummary? first;
      var retainedIdentity = true;
      for (var start = 0; start <= count; start += 24) {
        final end = min(start + 24, count);
        accumulator.add(
          models.sublist(start, end),
          (item) => item.id,
          (item) => item.updatedAt,
          (item) {
            afterMappings++;
            return item.toEntity();
          },
          complete: end - start < 24,
        );
        first ??= accumulator.items.first;
        retainedIdentity =
            retainedIdentity && identical(accumulator.items.first, first);
        if (end - start < 24) break;
      }
      after.stop();
      expect(retainedIdentity, isTrue);
      expect(afterMappings, count);
      expect(beforeMappings, {24: 48, 100: 340, 500: 5540}[count]);
      expect(accumulator.items, baselineItems);
      debugPrint(
        'STA-127 fixture n=$count mapping=$beforeMappings->$afterMappings '
        'cumulative-list-resorts=$beforeSorts->0 CPU-us=${baseline.elapsedMicroseconds}->${after.elapsedMicroseconds}',
      );
    });
  }

  test('cache reconciles changed versions, duplicate rows and final server deletion', () {
    final data = fixture(4);
    final accumulator = WorkoutSummaryAccumulator();
    var maps = 0;
    void add(
      List<WorkoutSummaryModel> items, {
      bool server = true,
      bool complete = false,
    }) => accumulator.add(
      items,
      (item) => item.id,
      (item) => item.updatedAt,
      (item) {
        maps++;
        return item.toEntity();
      },
      server: server,
      complete: complete,
    );
    add(data, server: false);
    final original = accumulator.items.first;
    add(data.take(2).toList());
    expect(maps, 4);
    expect(identical(accumulator.items.first, original), isTrue);
    final changed = WorkoutSummaryModel.fromEntity(
      data[2].toEntity().copyWith(name: 'changed', updatedAt: DateTime(2030)),
    );
    add([data.first, changed], complete: true);
    expect(maps, 5);
    expect(accumulator.items.map((item) => item.id), ['2', '0', '1']);
    expect(accumulator.items.first.name, 'changed');
    expect(accumulator.items.any((item) => item.id == '3'), isFalse);
  });
}
