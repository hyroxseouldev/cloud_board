import 'dart:async';

import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_firestore_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('catalog emits cache, retains older rows during paging, removes server deletions', () async {
    final source = _FirestoreSource([_workout('cached'), _workout('deleted')]);
    final repository = WorkoutRepositoryImpl(
      _Auth(),
      source,
      _Storage(),
      WorkoutLocalDataSource(await SharedPreferences.getInstance()),
    );
    final events = <List<Workout>>[];
    final done = Completer<void>();
    repository.watch().listen(events.add, onDone: done.complete);
    await Future<void>.delayed(Duration.zero);
    expect(events.single.map((w) => w.id).toSet(), {'cached', 'deleted'});
    source.pages.add((
      items: [WorkoutModel.fromEntity(_workout('new'))],
      complete: false,
    ));
    await Future<void>.delayed(Duration.zero);
    expect(events.last.map((w) => w.id).toSet(), {'new', 'cached', 'deleted'});
    source.pages.add((
      items: [
        WorkoutModel.fromEntity(_workout('new')),
        WorkoutModel.fromEntity(_workout('cached')),
      ],
      complete: true,
    ));
    await source.pages.close();
    await done.future;
    expect(events.last.map((w) => w.id).toSet(), {'new', 'cached'});
  });

  test('offline refresh preserves the cached catalog', () async {
    final source = _FirestoreSource([_workout('cached')]);
    final repository = WorkoutRepositoryImpl(
      _Auth(),
      source,
      _Storage(),
      WorkoutLocalDataSource(await SharedPreferences.getInstance()),
    );
    final loading = repository.load();
    source.pages.addError(StateError('offline'));
    await source.pages.close();
    expect((await loading).single.id, 'cached');
  });

  test('late pages do not overwrite edits or restore deleted rows; schedules wait for completion', () async {
    final repository = _Repository();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            const AuthUser(
              id: 'u',
              email: '',
              displayName: 'Coach',
              photoUrl: null,
            ),
          ),
        ),
        loadWorkoutsProvider.overrideWith(
          (ref) async => LoadWorkouts(repository),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(workoutControllerProvider, (_, _) {});
    repository.source.add([_workout('a'), _workout('b')]);
    await container.read(workoutControllerProvider.future);
    final controller = container.read(workoutControllerProvider.notifier);
    final edited = _workout('a').copyWith(name: 'Edited');
    controller.upsert(edited);
    controller.remove('b');
    var completed = false;
    final fullCatalog = controller.loadComplete().then((items) {
      completed = true;
      return items;
    });
    repository.source.add([_workout('a'), _workout('b'), _workout('c')]);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    expect(
      container
          .read(workoutControllerProvider)
          .requireValue
          .map((w) => w.id)
          .toSet(),
      {'a', 'c'},
    );
    expect(
      container
          .read(workoutControllerProvider)
          .requireValue
          .firstWhere((w) => w.id == 'a')
          .name,
      'Edited',
    );
    await repository.source.close();
    expect((await fullCatalog).map((w) => w.id).toSet(), {'a', 'c'});
  });
}

Workout _workout(String id) => Workout.empty(
  id,
  const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
).copyWith(modules: [WorkoutModule.empty('m')]);

class _FirestoreSource extends WorkoutFirestoreDataSource {
  _FirestoreSource(this.cached) : super(_UnusedFirestore());
  final List<Workout> cached;
  final pages = StreamController<({List<WorkoutModel> items, bool complete})>();
  @override
  Future<List<WorkoutModel>> loadCached(String userId) async =>
      cached.map(WorkoutModel.fromEntity).toList();
  @override
  Stream<({List<WorkoutModel> items, bool complete})> loadPages(
    String userId,
  ) => pages.stream;
}

class _UnusedFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  @override
  String get uid => 'u';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements WorkoutStorageDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements WorkoutRepository {
  final source = StreamController<List<Workout>>();
  @override
  Stream<List<Workout>> watch() => source.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
