import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

Workout get workout =>
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      name: 'Large class',
      countdownSeconds: 0,
      modules: [
        WorkoutModule.empty('m').copyWith(
          workSeconds: 60,
          sets: 1,
          restSeconds: 0,
          text: List.filled(20000, '내용').join(),
        ),
      ],
    );
PlaybackSessionModel model(String id) => PlaybackSessionModel.fromWorkout(
  id: id,
  ownerId: 'u',
  zoneId: 'main',
  targetDeviceIds: [],
  workout: workout,
  stepIndex: 0,
  durationMs: 60000,
  deviceId: 'phone',
);
Map<String, dynamic> split(PlaybackSessionModel model) => {
  ...model.toJson()..remove('workoutSnapshot'),
  'schemaVersion': 2,
  'snapshotId': model.id,
  'anchorServerMs': DateTime.now().millisecondsSinceEpoch,
};

void main() {
  test('v2 revisions and reconnect reuse snapshot; a different session fetches its own snapshot', () async {
    final db = _Database();
    final first = model('s');
    db.values['users/u/activeSession'] = split(first);
    db.values['users/u/playbackSnapshots/s'] = first.workoutSnapshot;
    final source = PlaybackRealtimeDataSource(db, 'u');
    final a = (await source.watchActive().first)!.toEntity();
    db.values['users/u/activeSession'] = {
      ...split(first),
      'revision': 2,
      'status': 'paused',
    };
    final b = (await source.watchActive().first)!.toEntity();
    expect(b.revision, 2);
    expect(identical(a.workout, b.workout), isTrue);
    expect(db.reads['users/u/playbackSnapshots/s'], 1);
    final next = model('next');
    db.values['users/u/activeSession'] = split(next);
    db.values['users/u/playbackSnapshots/next'] = {
      ...next.workoutSnapshot,
      'name': 'New class',
    };
    expect(
      (await source.watchActive().first)!.toEntity().workout.name,
      'New class',
    );
    expect(db.reads['users/u/playbackSnapshots/next'], 1);
  });

  test('v2 command transacts small state and preserves frozen workout and stale revision checks', () async {
    final db = _Database();
    final session = model('s');
    db.values['users/u/activeSession'] = split(session);
    db.values['users/u/playbackSnapshots/s'] = session.workoutSnapshot;
    final source = PlaybackRealtimeDataSource(db, 'u');
    final paused = await source.update(
      status: 'paused',
      deviceId: 'phone',
      expectedSessionId: 's',
      expectedRevision: 1,
    );
    expect(paused.status, 'paused');
    expect(paused.toEntity().workout, session.toEntity().workout);
    expect((db.lastTransaction as Map).containsKey('workoutSnapshot'), isFalse);
    expect(utf8.encode(jsonEncode(db.lastTransaction)).length, lessThan(1500));
    expect((db.lastTransaction as Map)['notificationCommand'], isA<Map>());
    await expectLater(
      source.update(
        status: 'playing',
        deviceId: 'phone',
        expectedSessionId: 's',
        expectedRevision: 1,
      ),
      throwsStateError,
    );
    db.beforeTransaction = () =>
        db.values['users/u/activeSession'] = {...split(session), 'revision': 9};
    await expectLater(
      source.update(
        status: 'playing',
        deviceId: 'phone',
        expectedSessionId: 's',
        expectedRevision: 2,
      ),
      throwsStateError,
    );
  });

  test('old sessions remain decodable; start only splits after all registered TVs advertise v2', () async {
    final db = _Database();
    final session = model('legacy');
    db.values['users/u/activeSession'] = session.toJson();
    final source = PlaybackRealtimeDataSource(db, 'u');
    expect((await source.watchActive().first)!.id, 'legacy');
    db.values['users/u/devices'] = {
      'tv': {'id': 'tv', 'mode': 'display', 'paired': true, 'online': false},
    };
    await source.start(model('old-tv'));
    expect(
      (db.values['users/u/activeSession'] as Map)['workoutSnapshot'],
      isNotNull,
    );
    (db.values['users/u/devices'] as Map)['tv']['playbackProtocol'] = 2;
    await source.start(model('new-tv'));
    expect(
      (db.values['users/u/activeSession'] as Map)['workoutSnapshot'],
      isNull,
    );
    expect(db.values['users/u/playbackSnapshots/new-tv'], isNotNull);
    expect(
      db.updates.last.keys,
      containsAll(['activeSession', 'playbackSnapshots/new-tv']),
    );
  });

  test('missing or mismatched snapshot fails instead of mixing data from another session', () async {
    final db = _Database();
    db.values['users/u/activeSession'] = {
      ...split(model('s')),
      'snapshotId': 'other',
    };
    await expectLater(
      PlaybackRealtimeDataSource(db, 'u').watchActive().first,
      throwsFormatException,
    );
    db.values['users/u/activeSession'] = split(model('s'));
    await expectLater(
      PlaybackRealtimeDataSource(db, 'u').watchActive().first,
      throwsFormatException,
    );
  });
}

class _Database implements FirebaseDatabase {
  final values = <String, Object?>{
    '.info/connected': true,
    '.info/serverTimeOffset': 0,
  };
  final reads = <String, int>{};
  final updates = <Map<String, Object?>>[];
  Object? lastTransaction;
  void Function()? beforeTransaction;
  @override
  DatabaseReference ref([String? path]) => _Reference(this, path ?? '');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DatabaseReference {
  _Reference(this.db, this.path);
  final _Database db;
  @override
  final String path;
  @override
  String? get key => path.split('/').last;
  @override
  DatabaseReference child(String path) => _Reference(db, '${this.path}/$path');
  @override
  DatabaseReference push() => child('event');
  @override
  Stream<DatabaseEvent> get onValue =>
      Stream.value(_Event(_Snapshot(db.values[path])));
  @override
  Future<DataSnapshot> get() async {
    db.reads[path] = (db.reads[path] ?? 0) + 1;
    return _Snapshot(db.values[path]);
  }

  Object? resolve(Object? value) => value is Map && value['.sv'] == 'timestamp'
      ? DateTime.now().millisecondsSinceEpoch
      : value is Map
      ? value.map((key, item) => MapEntry(key, resolve(item)))
      : value is List
      ? value.map(resolve).toList()
      : value;
  @override
  Future<void> update(Map<String, Object?> value) async {
    db.updates.add(value);
    for (final item in value.entries) {
      db.values['$path/${item.key}'] = resolve(item.value);
    }
  }

  @override
  Future<void> set(Object? value) async {
    db.values[path] = resolve(value);
  }

  @override
  Future<TransactionResult> runTransaction(
    TransactionHandler handler, {
    bool applyLocally = true,
  }) async {
    db.beforeTransaction?.call();
    final result = handler(db.values[path]);
    if (!result.aborted) {
      db.lastTransaction = result.value;
      db.values[path] = resolve(result.value);
    }
    return _Result(!result.aborted, _Snapshot(db.values[path]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
  @override
  bool get exists => value != null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Event implements DatabaseEvent {
  _Event(this.snapshot);
  @override
  final DataSnapshot snapshot;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Result implements TransactionResult {
  _Result(this.committed, this.snapshot);
  @override
  final bool committed;
  @override
  final DataSnapshot snapshot;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
