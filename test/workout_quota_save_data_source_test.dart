import 'dart:async';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_firestore_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

class _Firestore extends Fake implements FirebaseFirestore {
  final values = <String, Map<String, dynamic>>{};
  Object? error;
  Future<void> Function(String)? beforeRead;
  final sources = <Source>[];
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _Document(this, path);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final _Firestore store;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, '${this.path}/$path');
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);
  final _Firestore store;
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(store, '${this.path}/$path');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    store.sources.add(options!.source);
    await store.beforeRead?.call(path);
    if (store.error != null) throw store.error!;
    return _Snapshot(store.values[path]);
  }
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value;
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}

class _Functions extends Fake implements FirebaseFunctions {
  final calls = <Map<String, dynamic>>[];
  Object? error;
  Map<String, dynamic>? response;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, 'saveWorkout');
    return _Callable(this);
  }
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.functions);
  final _Functions functions;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final input = Map<String, dynamic>.from(parameters as Map);
    functions.calls.add(input);
    if (functions.error != null) throw functions.error!;
    return _Result({'workout': functions.response ?? input['workout']} as T);
  }
}

void main() {
  late _Firestore firestore;
  late _Functions functions;
  late WorkoutFirestoreDataSource source;
  late WorkoutModel draft;
  setUp(() {
    firestore = _Firestore();
    functions = _Functions();
    source = WorkoutFirestoreDataSource(firestore, functions: functions);
    draft = WorkoutModel.fromEntity(
      Workout.empty(
        'lesson',
        const WorkoutAuthor(id: 'owner', displayName: 'Coach', photoUrl: null),
      ).copyWith(
        name: 'Draft',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      ),
    );
  });
  test(
    'settings and previous workout reads start together and both gate save',
    () async {
      final reads = <String>[];
      final settingsGate = Completer<void>();
      final workoutGate = Completer<void>();
      firestore.beforeRead = (path) {
        reads.add(path);
        return path.endsWith('/settings/workout')
            ? settingsGate.future
            : workoutGate.future;
      };
      final saved = source.save('owner', draft);
      expect(reads, [
        'users/owner/settings/workout',
        'users/owner/workouts/lesson',
      ]);
      expect(functions.calls, isEmpty);
      workoutGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(functions.calls, isEmpty);
      settingsGate.complete();
      expect((await saved).name, draft.name);
      expect(functions.calls, hasLength(1));
    },
  );
  for (final failedPath in ['settings/workout', 'workouts/lesson']) {
    test('failed parallel $failedPath read never invokes save', () async {
      firestore.beforeRead = (path) async {
        if (path.endsWith(failedPath)) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        }
      };
      await expectLater(
        source.save('owner', draft),
        throwsA(isA<FirebaseException>()),
      );
      expect(firestore.sources, hasLength(2));
      expect(functions.calls, isEmpty);
    });
  }
  for (final contentOnly in [false, true]) {
    test(
      'save uses atomic callable with prepared schema (content-only $contentOnly)',
      () async {
        firestore.values['users/owner/settings/workout'] = {
          'contentOnly': contentOnly,
        };
        final saved = await source.save(
          'owner',
          draft,
          expectedUpdatedAt: draft.updatedAt,
        );
        final call = functions.calls.single;
        expect(call['ownerId'], 'owner');
        expect(call['settingsContentOnly'], contentOnly);
        expect(call['expectedUpdatedAt'], isNull);
        final wire = call['workout'] as Map;
        expect(wire['createdAt'], 1000);
        expect(wire['updatedAt'], 2000);
        expect(wire['schemaVersion'], contentOnly ? 2 : null);
        expect(wire.containsKey('brandL'), !contentOnly);
        expect(firestore.sources, everyElement(Source.server));
        expect(saved.name, draft.name);
        expect(saved.updatedAt, draft.updatedAt);
        expect(firestore.values.keys, ['users/owner/settings/workout']);
      },
    );
  }
  test('unknown stored fields and legacy settings survive with the exact server revision', () async {
    final previous = {
      ...draft.toJson(),
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(1500),
      'brandL': 'Stored brand',
      'futureMetadata': {
        'retained': true,
        'timestamp': Timestamp.fromMillisecondsSinceEpoch(1234),
      },
    };
    firestore.values['users/owner/workouts/lesson'] = previous;
    await source.save(
      'owner',
      draft,
      requireExisting: true,
      expectedUpdatedAt: DateTime.fromMillisecondsSinceEpoch(1500),
    );
    final call = functions.calls.single;
    expect(call['expectedUpdatedAt'], 1500);
    expect(call['requireExisting'], isTrue);
    expect((call['workout'] as Map)['brandL'], 'Stored brand');
    expect((call['workout'] as Map)['futureMetadata'], {
      'retained': true,
      'timestamp': {'__timestampMillis': 1234},
    });
    expect(firestore.values['users/owner/workouts/lesson'], previous);
  });
  test(
    'a stale editor overwrites the same ID with its complete edited content',
    () async {
      final edited = WorkoutModel.fromEntity(
        draft.toEntity().copyWith(
          name: 'Latest explicit save',
          folder: 'Edited folder',
          modules: [
            WorkoutModule.empty('edited-slide').copyWith(
              name: 'Edited slide',
              text: 'Preserve every edit',
              workSeconds: 90,
            ),
          ],
        ),
      );
      firestore.values['users/owner/workouts/lesson'] = {
        ...draft.toJson(),
        'name': 'Another device saved',
        'updatedAt': Timestamp.fromMillisecondsSinceEpoch(3000),
        'futureMetadata': {'retained': true},
      };

      final saved = await source.save(
        'owner',
        edited,
        expectedUpdatedAt: DateTime.fromMillisecondsSinceEpoch(1500),
        requireExisting: true,
      );

      final call = functions.calls.single;
      expect(call['expectedUpdatedAt'], 3000);
      expect((call['workout'] as Map)['futureMetadata'], {'retained': true});
      expect(saved.toEntity(), edited.toEntity());
      expect(saved.id, 'lesson');
      expect(saved.name, 'Latest explicit save');
    },
  );
  test(
    'a deleted workout reaches the server for recreation with the same ID',
    () async {
      final saved = await source.save(
        'owner',
        draft,
        expectedUpdatedAt: DateTime.fromMillisecondsSinceEpoch(1500),
        requireExisting: true,
      );

      final call = functions.calls.single;
      expect(call['expectedUpdatedAt'], isNull);
      expect(saved.toEntity(), draft.toEntity());
      expect(saved.id, 'lesson');
    },
  );
  test(
    'quota rejection preserves the unsaved draft and structured limit error',
    () async {
      functions.error = FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'Limit',
        details: {'resource': 'workouts', 'limit': 7, 'used': 7},
      );
      await expectLater(
        source.save('owner', draft),
        throwsA(
          isA<FirebaseFunctionsException>().having(
            (e) => e.details,
            'details',
            {'resource': 'workouts', 'limit': 7, 'used': 7},
          ),
        ),
      );
      expect(draft.name, 'Draft');
      expect(firestore.values, isEmpty);
    },
  );
  test('transient server failure stays retryable without inventing an editor conflict', () async {
    functions.error = FirebaseFunctionsException(
      code: 'aborted',
      message: 'Transaction retry exhausted',
    );
    await expectLater(
      source.save('owner', draft),
      throwsA(same(functions.error)),
    );
    functions.error = null;
    functions.response = {
      ...draft.toJson(),
      'name': 'Server result',
      'createdAt': 1000,
      'updatedAt': 2000,
    };
    expect((await source.save('owner', draft)).name, 'Server result');
  });
  test(
    'ifAbsent import returns existing customized data without a second create',
    () async {
      firestore.values['users/owner/workouts/lesson'] = {
        ...draft.toJson(),
        'name': 'User edited sample',
      };
      expect(
        (await source.save('owner', draft, ifAbsent: true)).name,
        'User edited sample',
      );
      expect(functions.calls, isEmpty);
    },
  );
  test(
    'offline failures are retryable without a queued legacy direct write',
    () async {
      firestore.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await expectLater(
        source.save('owner', draft),
        throwsA(isA<FirebaseException>()),
      );
      expect(functions.calls, isEmpty);
      firestore.error = null;
      expect((await source.save('owner', draft)).name, 'Draft');
      expect(functions.calls, hasLength(1));
    },
  );
}
