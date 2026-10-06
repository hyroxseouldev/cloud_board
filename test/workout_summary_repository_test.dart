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
  test(
    'catalog warms only recent details and repeated opens reuse those reads',
    () async {
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
      expect(result.last.first.durationSeconds, 120);
      await Future<void>.delayed(Duration.zero);
      expect(source.detailReads, 2);
      expect((await repo.loadOne('w29'))?.id, 'w29');
      final reads = source.detailReads;
      await repo.loadOne('w29');
      expect(source.detailReads, reads);
      expect(source.detailReads, lessThanOrEqualTo(3));
    },
  );
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
    await expectLater(
      repo.watchSummaries(requireServer: true).toList(),
      throwsA(isA<StateError>()),
    );
    expect(source.detailReads, 0);
  });

  test('warm and foreground reads share a request; changed versions and accounts invalidate details', () async {
    final source = _Source()..detailGate = Completer<void>();
    final auth = _Auth();
    final repo = WorkoutRepositoryImpl(
      auth,
      source,
      _Storage(),
      WorkoutLocalDataSource(await SharedPreferences.getInstance()),
    );
    await repo.watchSummaries().toList();
    await Future<void>.delayed(Duration.zero);
    expect(source.detailReads, 2);
    final opening = repo.loadOne('w0');
    final secondOpening = repo.loadOne('w0');
    expect(identical(opening, secondOpening), isTrue);
    expect(source.detailReads, 2);
    source.detailGate!.complete();
    expect((await opening)?.ownerId, 'u');
    source.server[0] = source.server[0].copyWith(
      name: 'Updated elsewhere',
      updatedAt: DateTime(2030),
    );
    await repo.watchSummaries().toList();
    expect((await repo.loadOne('w0'))?.name, 'Updated elsewhere');
    expect(source.detailReads, 3);
    auth.uid = 'other';
    expect((await repo.loadOne('w0'))?.ownerId, 'other');
    expect(source.detailReads, 4);
    source.server.removeAt(0);
    await repo.watchSummaries().toList();
    expect(await repo.loadOne('w0'), isNull);
  });
}

class _Source extends WorkoutFirestoreDataSource {
  _Source() : super(_Firestore());
  List<WorkoutSummaryModel> cached = [];
  final server = List.generate(
    30,
    (i) =>
        workout('w$i')
            .copyWith(updatedAt: DateTime(2026).subtract(Duration(minutes: i))),
  );
  Completer<void>? detailGate;
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
    final items = server
        .map((w) => WorkoutSummaryModel.fromEntity(summarizeWorkout(w)))
        .toList();
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
    await detailGate?.future;
    final detail = server.where((w) => w.id == id).firstOrNull;
    return detail == null
        ? null
        : WorkoutModel.fromEntity(detail.copyWith(ownerId: uid));
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
  String uid = 'u';
  @override
  User get currentUser => _User(uid);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
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
