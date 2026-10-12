// Narrow Firestore test doubles exercise the production transaction boundary.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_preferences_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final old = const WorkoutPreferences(brandL: 'Canonical');
  final legacy = const WorkoutPreferences(brandL: 'Installed app edit');
  late _Firestore db;
  late WorkoutPreferencesDataSource source;
  setUp(() {
    db = _Firestore({
      'users/owner': {'uid': 'owner', 'workoutSettings': legacy.toJson()},
      'users/owner/settings/workout': {
        'schemaVersion': 1,
        'revision': 3,
        'contentOnly': false,
        'preferences': old.toJson(),
      },
    });
    source = WorkoutPreferencesDataSource(db, _Storage(), _Auth());
  });
  test(
    'accepted old-client edits are visible before the canonical bridge runs',
    () async {
      final loaded = (await source.load('owner'))!;
      expect(loaded.brandL, legacy.brandL);
      expect(loaded.revision, 3);
    },
  );
  test(
    'a pending legacy edit cannot be overwritten by a stale settings editor',
    () async {
      final loaded = await source.loadForEditing('owner');
      db.documents['users/owner']!['workoutSettings'] = legacy
          .copyWith(brandL: 'Newer edit')
          .toJson();
      await expectLater(
        source.save('owner', loaded.copyWith(brandL: 'Stale save')),
        throwsStateError,
      );
      expect(db.writes, 0);
    },
  );
  for (final hasCanonical in [false, true]) {
    test(
      'an initially absent mirror detects a legacy write with canonical=$hasCanonical',
      () async {
        db.documents['users/owner']!.remove('workoutSettings');
        if (!hasCanonical) {
          db.documents.remove('users/owner/settings/workout');
        }
        final loaded = await source.loadForEditing('owner');
        db.documents['users/owner']!['workoutSettings'] = legacy.toJson();

        await expectLater(
          source.save('owner', loaded.copyWith(brandL: 'Stale save')),
          throwsStateError,
        );
        expect(db.writes, 0);
        expect(
          db.documents['users/owner']!['workoutSettings']['brandL'],
          legacy.brandL,
        );
      },
    );
    test(
      'a refresh cannot replace an absent editor baseline with canonical=$hasCanonical',
      () async {
        db.documents['users/owner']!.remove('workoutSettings');
        if (!hasCanonical) {
          db.documents.remove('users/owner/settings/workout');
        }
        final loaded = await source.loadForEditing('owner');
        db.documents['users/owner']!['workoutSettings'] = legacy.toJson();

        final refreshed = (await source.load('owner', fresh: true))!;
        expect(refreshed.brandL, legacy.brandL);
        expect(refreshed.revision, loaded.revision);
        await expectLater(
          source.save('owner', loaded.copyWith(brandL: 'Stale save')),
          throwsStateError,
        );
        expect(db.writes, 0);
      },
    );
  }
  test(
    'a refresh retains the existing mirror baseline until the bridge advances',
    () async {
      final loaded = await source.loadForEditing('owner');
      final newer = legacy.copyWith(brandL: 'Newer installed app edit');
      db.documents['users/owner']!['workoutSettings'] = newer.toJson();
      final refreshed = (await source.load('owner', fresh: true))!;
      expect(refreshed.brandL, newer.brandL);
      await expectLater(
        source.save('owner', loaded.copyWith(brandL: 'Stale save')),
        throwsStateError,
      );
      expect(db.writes, 0);

      db.documents['users/owner/settings/workout']!.addAll({
        'revision': 4,
        'preferences': newer.toJson(),
      });
      final bridged = (await source.load('owner', fresh: true))!;
      final saved = await source.save(
        'owner',
        bridged.copyWith(brandL: 'Current after bridge'),
      );
      expect(saved.revision, 5);
      expect(db.writes, 2);
    },
  );
  test('an unchanged absent mirror allows the first settings save', () async {
    db.documents['users/owner']!.remove('workoutSettings');
    db.documents.remove('users/owner/settings/workout');
    final loaded = await source.loadForEditing('owner');

    final saved = await source.save(
      'owner',
      loaded.copyWith(brandL: 'First settings'),
    );

    expect(saved.revision, 1);
    expect(db.writes, 2);
    expect(
      db.documents['users/owner']!['workoutSettings']['brandL'],
      'First settings',
    );
  });
  test('a current edit updates canonical and mirror, then guards the next edit too', () async {
    final loaded = await source.loadForEditing('owner');
    final saved = await source.save(
      'owner',
      loaded.copyWith(brandL: 'Current'),
    );
    expect(saved.revision, 4);
    expect(
      db.documents['users/owner']!['workoutSettings']['brandL'],
      'Current',
    );
    expect(
      db.documents['users/owner/settings/workout']!['preferences']['brandL'],
      'Current',
    );
    db.documents['users/owner']!['workoutSettings'] = legacy.toJson();
    await expectLater(
      source.save('owner', saved.copyWith(brandL: 'Stale again')),
      throwsStateError,
    );
    expect(db.writes, 2);
  });
}

class _Firestore implements FirebaseFirestore {
  _Firestore(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  int writes = 0;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _Document(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => transactionHandler(_Transaction(this));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  _Transaction(this.db);
  final _Firestore db;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) => reference.get();
  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T value, [
    SetOptions? options,
  ]) {
    db.documents[reference.path] = {
      if (options?.merge == true) ...?db.documents[reference.path],
      ...value as Map<String, dynamic>,
    };
    db.writes++;
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Document implements DocumentReference<Map<String, dynamic>> {
  _Document(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(db.documents[path]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
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
  String get uid => 'owner';
  @override
  bool get isAnonymous => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements FirebaseStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
