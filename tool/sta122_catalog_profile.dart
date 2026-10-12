import 'dart:math';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_firestore_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_summary_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Physical-device CPU fixture exercising the actual repository implementation.
/// Baseline (before STA-127) data source emits cumulative DTO pages. Build the
/// changed revision with --dart-define=BENCH_DELTA=true to use its delta contract.
/// All catalog/detail reads below are local fakes: this measures CPU and mapping
/// work, not Firestore network latency, billing, or production account behavior.
Future<Map<String, Object>> profileCatalog() async {
  const delta = bool.fromEnvironment('BENCH_DELTA');
  final preferences = await SharedPreferences.getInstance();
  final results = <Map<String, Object>>[];
  for (final count in [24, 100, 500]) {
    final times = <int>[];
    var mappings = 0;
    var queries = 0;
    var dtoEmissions = 0;
    var warmedDetails = 0;
    for (var run = 0; run < 12; run++) {
      final source = _CatalogSource(count, delta: delta);
      final repository = WorkoutRepositoryImpl(
        _CatalogAuth(),
        source,
        _UnusedStorage(),
        WorkoutLocalDataSource(preferences),
      );
      final stopwatch = Stopwatch()..start();
      final finalPage = await repository
          .watchSummaries(requireServer: true)
          .last;
      stopwatch.stop();
      if (finalPage.length != count ||
          finalPage.map((item) => item.id).toSet().length != count) {
        throw StateError('Incomplete catalog fixture');
      }
      // Discard the first two warmups. Retain raw samples for honest comparisons.
      if (run >= 2) times.add(stopwatch.elapsedMicroseconds);
      mappings = source.mappings;
      queries = source.queries;
      dtoEmissions = source.dtoEmissions;
      warmedDetails = source.detailReads;
    }
    final ordered = [...times]..sort();
    results.add({
      'workouts': count,
      'repositoryCpuMicroseconds': times,
      'medianMicroseconds': ordered[ordered.length ~/ 2],
      'p95Microseconds': ordered[(ordered.length * .95).ceil() - 1],
      'networkRequests': 0,
      'simulatedSummaryQueries': queries,
      'uniqueSummaryDocuments': count,
      'emittedDtos': dtoEmissions,
      'toEntityCalls': mappings,
      'simulatedWarmDetailReads': warmedDetails,
    });
  }
  return {
    'fixture': 'STA-127 actual repository CPU',
    'deltaPages': delta,
    'cases': results,
  };
}

class _CatalogSource extends WorkoutFirestoreDataSource {
  _CatalogSource(int count, {required this.delta}) : super(_UnusedFirestore()) {
    rows = List.generate(
      count,
      (index) => _CountingSummary(index, () => mappings++),
    );
  }
  final bool delta;
  late final List<WorkoutSummaryModel> rows;
  int mappings = 0, queries = 0, dtoEmissions = 0, detailReads = 0;
  @override
  Future<bool> hasSummaryCatalog(String userId) async => true;
  @override
  Future<List<WorkoutSummaryModel>> loadCachedSummaries(String userId) async =>
      [];
  @override
  Stream<({List<WorkoutSummaryModel> items, bool complete})> loadSummaryPages(
    String userId,
  ) async* {
    for (
      var offset = 0;
      offset <= rows.length;
      offset += WorkoutFirestoreDataSource.pageSize
    ) {
      final end = min(
        offset + WorkoutFirestoreDataSource.pageSize,
        rows.length,
      );
      final page = rows.sublist(delta ? offset : 0, end);
      queries++;
      dtoEmissions += page.length;
      final complete = end - offset < WorkoutFirestoreDataSource.pageSize;
      yield (items: page, complete: complete);
      if (complete) return;
    }
  }

  @override
  Future<WorkoutModel?> loadOne(
    String userId,
    String workoutId, {
    bool requireServer = false,
  }) async {
    detailReads++;
    return null;
  }
}

class _CountingSummary extends WorkoutSummaryModel {
  _CountingSummary(int index, this.onMap)
    : super(
        id: 'fixture-$index',
        name: '수업 $index',
        folder: '폴더 ${index % 5}',
        imageSource: '',
        moduleCount: 12,
        durationSeconds: 1200,
        updatedAt: DateTime(2026, 10, 1).subtract(Duration(minutes: index)),
      );
  final void Function() onMap;
  @override
  WorkoutSummary toEntity() {
    onMap();
    return super.toEntity();
  }
}

class _UnusedFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CatalogAuth implements FirebaseAuth {
  @override
  User get currentUser => _CatalogUser();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CatalogUser implements User {
  @override
  String get uid => 'sta122-catalog-fixture';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedStorage implements WorkoutStorageDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
