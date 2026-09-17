import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_summary_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_firestore_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';

Workout workout(String id) =>
    Workout.empty(
      id,
      const WorkoutAuthor(id: 'u', displayName: '', photoUrl: null),
    ).copyWith(
      name: '검색 대상 $id',
      folder: '폴더 $id',
      modules: [
        WorkoutModule.empty('m')
            .copyWith(workSeconds: 30, sets: 3, restSeconds: 10),
      ],
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('one-shot detail loads survive unobserved frames and duplicate actions are suppressed', () async {
    final repo = _PendingDetail();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            const AuthUser(id: 'u', email: '', displayName: '', photoUrl: null),
          ),
        ),
        loadWorkoutsProvider.overrideWith((ref) async => LoadWorkouts(repo)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(workoutActionControllerProvider, (_, _) {});
    final actions = container.read(workoutActionControllerProvider.notifier);
    final first = actions.prepare('w');
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    await container.pump();
    expect(await actions.prepare('w'), isNull);
    expect(repo.reads, 1);
    repo.gate.complete(workout('w'));
    expect((await first)?.id, 'w');
    expect(container.read(workoutActionControllerProvider).hasError, isFalse);
  });
  test('catalog streams lightweight summaries; details are requested by ID and offline preparation does not block', () async {
    final source = _Source();
    final repo = WorkoutRepositoryImpl(
      _Auth(),
      source,
      _Storage(),
      WorkoutLocalDataSource(await SharedPreferences.getInstance()),
    );
    final result = await repo.watchSummaries().toList();
    expect(result.last.length, 30);
    expect(result.last.any((w) => w.name.contains('w29')), isTrue);
    expect(result.last.first.durationSeconds, 110);
    expect(source.detailReads, 0);
    expect(source.offlineChecks, lessThanOrEqualTo(2));
    expect((await repo.loadOne('w29'))?.id, 'w29');
    expect(source.detailReads, 1);
    source.offlineGate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(source.offlineChecks, 30);
  });
  test('summary cache survives failed refresh without querying full server documents', () async {
    final source = _Source()
      ..cached = [
        WorkoutSummaryModel.fromEntity(summarizeWorkout(workout('cached'))),
      ]
      ..fail = true;
    final repo = WorkoutRepositoryImpl(
      _Auth(),
      source,
      _Storage(),
      WorkoutLocalDataSource(await SharedPreferences.getInstance()),
    );
    final result = await repo.watchSummaries().toList();
    expect(result.last.single.id, 'cached');
    expect(source.detailReads, 0);
    expect(source.offlineChecks, 0);
  });
}

class _Source extends WorkoutFirestoreDataSource {
  _Source() : super(_Firestore());
  List<WorkoutSummaryModel> cached = [];
  bool fail = false;
  int detailReads = 0, offlineChecks = 0;
  final offlineGate = Completer<void>();
  @override
  Future<bool> hasSummaryCatalog(String id) async => true;
  @override
  Future<List<WorkoutSummaryModel>> loadCachedSummaries(String id) async =>
      cached;
  @override
  Stream<({List<WorkoutSummaryModel> items, bool complete})> loadSummaryPages(
    String id,
  ) async* {
    if (fail) throw StateError('offline');
    final items = List.generate(
      30,
      (i) => WorkoutSummaryModel.fromEntity(summarizeWorkout(workout('w$i'))),
    );
    yield (items: items.take(24).toList(), complete: false);
    yield (items: items, complete: true);
  }

  @override
  Future<void> ensureOfflineDetail(
    String uid,
    String id,
    DateTime version,
  ) async {
    offlineChecks++;
    await offlineGate.future;
  }

  @override
  Future<WorkoutModel?> loadOne(String uid, String id) async {
    detailReads++;
    return WorkoutModel.fromEntity(workout(id));
  }

  @override
  Stream<({List<WorkoutModel> items, bool complete})> loadPages(String uid) =>
      throw StateError('must not read full server catalog');
}

class _Firestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth implements FirebaseAuth {
  @override
  User get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _User implements User {
  @override
  String get uid => 'u';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Storage implements WorkoutStorageDataSource {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _PendingDetail implements WorkoutRepository {
  final gate = Completer<Workout?>();
  int reads = 0;
  @override
  Future<Workout?> loadOne(String id) {
    reads++;
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
