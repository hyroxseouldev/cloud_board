// This harness is injected into an exact historical checkout. All application
// imports resolve to that checkout's original, unmodified sources and lockfile.
// It intentionally uses only the fixed timer available in the September build;
// inventing modern maximum/open timer scenarios would misrepresent that client.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_firestore_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_preferences_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

final _encoder = JsonEncoder.withIndent('  ', (value) {
  if (value is Timestamp) {
    return {'__timestampMillis': value.millisecondsSinceEpoch};
  }
  if (value is FieldValue) return {'__serverTimestamp': true};
  throw UnsupportedError(
    'Unexpected historical wire type: ${value.runtimeType}',
  );
});

void _write(String name, Map<String, dynamic> value) {
  final file = File(
    '${const String.fromEnvironment('HISTORICAL_OUTPUT')}/$name',
  );
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${_encoder.convert(value)}\n');
}

Workout _workout(String id) =>
    Workout.empty(
      id,
      const WorkoutAuthor(id: 'owner', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      name: 'Workout',
      brandL: 'Saved brand',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
      modules: [WorkoutModule.empty('slide')],
    );

void main() {
  test('capture original create/update/duplicate transactions', () async {
    final scenarios = <Map<String, dynamic>>[];
    for (final contentOnly in [false, true]) {
      final id = '${contentOnly ? 'content' : 'legacy'}-fixed';
      final db = _Firestore({
        'users/owner/settings/workout': {'contentOnly': contentOnly},
      });
      final source = WorkoutFirestoreDataSource(db);
      final original = _workout(id);
      final operations = {
        'create': original,
        'update': original.copyWith(
          name: 'Edited workout',
          brandL: 'Preview only',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
        ),
        'duplicate': original.copyWith(
          id: '$id-copy',
          name: '${original.name} 복사',
          createdAt: DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true),
          modules: original.modules
              .map((m) => m.copyWith(id: '${m.id}c'))
              .toList(),
        ),
      };
      final writes = <Map<String, dynamic>>[];
      for (final entry in operations.entries) {
        await source.save('owner', WorkoutModel.fromEntity(entry.value));
        final persisted =
            db.documents['users/owner/workouts/${entry.value.id}']!;
        final summary =
            db.documents['users/owner/workoutSummaries/${entry.value.id}']!;
        expect(summary.containsKey('durationKind'), isFalse);
        expect(summary['durationSeconds'], 60);
        if (!contentOnly) expect(persisted['brandL'], 'Saved brand');
        writes.add({
          'operation': entry.key,
          'workout': persisted,
          'summary': summary,
        });
      }
      scenarios.add({
        'name': id,
        'contentOnly': contentOnly,
        'durationKind': 'fixed',
        'writes': writes,
      });
    }
    _write('workout.json', {'format': 1, 'scenarios': scenarios});
  });

  test('capture original settings and both supported playback envelopes', () async {
    final db = _Firestore({});
    await WorkoutPreferencesDataSource(
      db,
      _Storage(),
      _Auth(),
    ).save('owner', const WorkoutPreferences());
    final workout = _workout('contract-workout').copyWith(
      name: 'Contract',
      brandL: 'CloudBoard',
      author: const WorkoutAuthor(
        id: 'owner',
        displayName: 'Test',
        photoUrl: null,
      ),
    );
    final playback = <Map<String, dynamic>>[];
    for (final split in [false, true]) {
      // The historical data source exposes the actual capability selector. The
      // envelope below is its stable model/snapshot protocol, excluding the
      // short-lived notificationCommand added only while committing a start.
      expect(
        supportsSplitPlayback({
          'tv': {'paired': true, if (split) 'playbackProtocol': 2},
        }),
        split,
      );
      final model = PlaybackSessionModel.fromWorkout(
        id: split ? 'session-v2' : 'session-v1',
        ownerId: 'owner',
        zoneId: 'main',
        targetDeviceIds: ['tv'],
        workout: workout,
        stepIndex: 0,
        durationMs: 60000,
        deviceId: 'phone',
      );
      final state = model.toJson()..['anchorServerMs'] = {'.sv': 'timestamp'};
      Map<String, dynamic>? snapshot;
      if (split) {
        state.remove('workoutSnapshot');
        state.addAll({
          'schemaVersion': 2,
          'snapshotId': model.id,
          'workoutId': model.workoutSnapshot['id'],
          'workoutName': model.workoutSnapshot['name'],
        });
        snapshot = {
          ...model.workoutSnapshot,
          '_storedAtMs': {'.sv': 'timestamp'},
        };
      }
      playback.add({'split': split, 'state': state, 'snapshot': snapshot});
    }
    _write('app.json', {
      'format': 1,
      'settings': db.documents['users/owner/settings/workout'],
      'playback': playback,
    });
  });
}

// A recording transport only: serialization/save policy runs in the original
// application data sources, including full-document transaction.set writes.
class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _Document(this, path);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => transactionHandler(_Transaction(this));
}

class _Transaction extends Fake implements Transaction {
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
    return this;
  }
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(db, '$path/$collectionPath');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(db.documents[path]);
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(db, '${this.path}/$path');
}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'owner';
  @override
  bool get isAnonymous => false;
}

class _Storage extends Fake implements FirebaseStorage {}
