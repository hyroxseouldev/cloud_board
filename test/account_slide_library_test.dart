import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_library_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/account_slide_editor_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';

void main() {
  test('legacy migration uploads images, preserves local originals, retries safely and syncs between devices', () async {
    final source = _Local(), cloud = _Cloud(), auth = _Auth();
    addTearDown(cloud.events.close);
    final original = WorkoutModule.empty('a')
        .copyWith(imageSource: 'inline-image', favorite: true);
    final local = LocalSlideEditorRepository(source);
    await local.saveTemplates('owner', [original]);
    final repository = AccountSlideEditorRepository(
      source,
      auth,
      cloud,
      _Storage(),
    );
    cloud.fail = true;
    await expectLater(repository.loadTemplates('owner'), throwsStateError);
    expect(await local.loadTemplates('owner'), [original]);
    expect(
      source.values.keys.where((k) => k.startsWith('account-import')),
      isEmpty,
    );
    cloud.fail = false;
    final migrated = await repository.loadTemplates('owner');
    expect(migrated.single.imageSource, 'https://image/inline-image');
    expect(await local.loadTemplates('owner'), [original]);
    final calls = cloud.calls;
    await repository.loadTemplates('owner');
    expect(cloud.calls, calls);
    final second = AccountSlideEditorRepository(
      _Local(),
      auth,
      cloud,
      _Storage(),
    );
    expect(await second.loadTemplates('owner'), migrated);
    final seen = <List<WorkoutModule>>[];
    final subscription = second.watchTemplates('owner').listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    final updated = migrated.single.copyWith(name: 'Updated on PC');
    await repository.saveTemplates('owner', [updated], previous: migrated);
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.single.name, 'Updated on PC');
    expect(cloud.lastChanges.single['id'], 'a');
    await subscription.cancel();
  });

  test(
    'item patches never delete unrelated remote entries and styles omit images',
    () async {
      final cloud = _Cloud(), auth = _Auth();
      addTearDown(cloud.events.close);
      final repo = AccountSlideEditorRepository(
        _Local(),
        auth,
        cloud,
        _Storage(),
      );
      final a = WorkoutModule.empty('a'), b = WorkoutModule.empty('b');
      await repo.saveTemplates('owner', [a], previous: []);
      await repo.saveTemplates('owner', [b], previous: []);
      await repo.saveTemplates('owner', [], previous: [a]);
      expect((await repo.loadTemplates('owner')).map((m) => m.id), ['b']);
      await repo.saveStyles('owner', [
        a.copyWith(imageSource: 'raw', favorite: true),
      ], previous: []);
      expect((await repo.loadStyles('owner')).single.imageSource, '');
      expect((await repo.loadStyles('owner')).single.favorite, false);
      expect((await repo.loadTemplates('owner')).single.id, 'b');
    },
  );

  test('account mismatch blocks reads/writes, including sign-out during image upload', () async {
    final cloud = _Cloud(), auth = _Auth();
    addTearDown(cloud.events.close);
    final storage = _Storage()..beforeUpload = () => auth.user = null;
    final repo = AccountSlideEditorRepository(_Local(), auth, cloud, storage);
    await expectLater(
      repo.loadTemplates('other'),
      throwsA(isA<LibraryFailure>()),
    );
    await expectLater(
      repo.saveTemplates('owner', [
        WorkoutModule.empty('x').copyWith(imageSource: 'raw'),
      ], previous: []),
      throwsA(isA<LibraryFailure>()),
    );
    expect(cloud.calls, 0);
  });
}

class _Local extends SlideEditorLocalDataSource {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class _User extends Fake implements User {
  @override
  String get uid => 'owner';
}

class _Auth extends Fake implements FirebaseAuth {
  User? user = _User();
  @override
  User? get currentUser => user;
}

class _Firestore extends Fake implements FirebaseFirestore {}

class _Functions extends Fake implements FirebaseFunctions {}

class _FirebaseStorage extends Fake implements FirebaseStorage {}

class _Storage extends WorkoutStorageDataSource {
  _Storage() : super(_FirebaseStorage());
  void Function()? beforeUpload;
  @override
  Future<String> uploadImage(String uid, String id, String source) async {
    beforeUpload?.call();
    return WorkoutStorageDataSource.needsUpload(source)
        ? 'https://image/$source'
        : source;
  }
}

class _Cloud extends SlideLibraryDataSource {
  _Cloud() : super(_Firestore(), _Functions());
  final values = <String, Map<String, Map<String, dynamic>>>{};
  final events = StreamController<void>.broadcast();
  int calls = 0;
  bool fail = false;
  List<Map<String, dynamic>> lastChanges = [];
  @override
  Future<List<Map<String, dynamic>>> load(String uid, String kind) async =>
      values['$uid/$kind']?.values.toList() ?? [];
  @override
  Stream<List<Map<String, dynamic>>> watch(String uid, String kind) async* {
    yield await load(uid, kind);
    yield* events.stream.asyncMap((_) => load(uid, kind));
  }

  @override
  Future<void> mutate(
    String uid,
    String kind,
    List<Map<String, dynamic>> changes, {
    bool migration = false,
  }) async {
    calls++;
    if (fail) throw StateError('offline');
    lastChanges = changes;
    final store = values.putIfAbsent('$uid/$kind', () => {});
    for (final c in changes) {
      if (migration && store.containsKey(c['id'])) continue;
      if (c['value'] == null) {
        store.remove(c['id']);
      } else {
        store[c['id'] as String] = c['value'] as Map<String, dynamic>;
      }
    }
    events.add(null);
  }
}
