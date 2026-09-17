import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Database database;
  late PlaybackRealtimeDataSource source;
  late PlaybackSessionModel model;
  setUp(() {
    database = _Database();
    source = PlaybackRealtimeDataSource(database, 'coach');
    model = PlaybackSessionModel.fromWorkout(
      id: 'class',
      ownerId: 'coach',
      zoneId: 'main',
      targetDeviceIds: ['tv'],
      workout: Workout.empty(
        'workout',
        const WorkoutAuthor(id: 'coach', displayName: 'Coach', photoUrl: null),
      ).copyWith(countdownSeconds: 0, modules: [WorkoutModule.empty('slide')]),
      stepIndex: 0,
      durationMs: 60000,
      deviceId: 'controller',
    );
  });

  test(
    'class starts and pauses when metadata get is denied but SDK events work',
    () async {
      final started = await source.start(model);
      expect(started.id, 'class');
      expect(database.writes, 1);
      expect(await source.hasRunningSession(), isTrue);
      final paused = await source.update(
        status: 'paused',
        deviceId: 'controller',
        expectedSessionId: started.id,
        expectedRevision: started.revision,
      );
      expect(paused.status, 'paused');
      expect(paused.revision, started.revision + 1);
      expect(paused.remainingMs, inInclusiveRange(58000, 60000));
      expect(database.metadataGets, 0);
      expect(database.transactions, 1);
    },
  );

  test('disconnected controller cannot start or submit a command', () async {
    database.values['.info/connected'] = false;
    await expectLater(source.start(model), throwsStateError);
    await expectLater(
      source.update(
        status: 'paused',
        deviceId: 'controller',
        expectedSessionId: model.id,
        expectedRevision: model.revision,
      ),
      throwsStateError,
    );
    expect(database.writes, 0);
    expect(database.transactions, 0);
  });

  test('registration guard remains enforced after metadata fix', () async {
    database.values['users/coach/devices'] = {
      'tv': {'paired': false},
    };
    await expectLater(source.start(model), throwsStateError);
    expect(database.writes, 0);
  });
}

/// Models the Apple SDK distinction: .info values are delivered by listeners,
/// while a one-shot server get of that virtual path is rejected.
class _Database extends Fake implements FirebaseDatabase {
  final values = <String, Object?>{
    '.info/connected': true,
    '.info/serverTimeOffset': 0,
    'users/coach/devices': {
      'tv': {'paired': true},
    },
  };
  int metadataGets = 0;
  int writes = 0;
  int transactions = 0;
  @override
  DatabaseReference ref([String? path]) => _Reference(this, path ?? '');
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.database, this.path);
  final _Database database;
  @override
  final String path;
  @override
  String get key => path.split('/').last;
  @override
  DatabaseReference child(String path) =>
      _Reference(database, '${this.path}/$path');
  @override
  DatabaseReference push() => child('event');
  @override
  Stream<DatabaseEvent> get onValue =>
      Stream.value(_Event(database.values[path]));
  @override
  Future<DataSnapshot> get() async {
    if (path.startsWith('.info/')) {
      database.metadataGets++;
      throw FirebaseException(
        plugin: 'firebase_database',
        code: 'permission-denied',
      );
    }
    return _Snapshot(database.values[path]);
  }

  @override
  Future<void> update(Map<String, Object?> values) async {
    database.writes++;
    for (final entry in values.entries) {
      var value = entry.value;
      if (entry.key == 'activeSession') {
        value = Map<String, dynamic>.from(value! as Map)
          ..['anchorServerMs'] = DateTime.now().millisecondsSinceEpoch;
      }
      database.values['$path/${entry.key}'] = value;
    }
  }

  @override
  Future<TransactionResult> runTransaction(
    TransactionHandler handler, {
    bool applyLocally = true,
  }) async {
    database.transactions++;
    final transaction = handler(database.values[path]);
    if (transaction.aborted) return _Result(false, database.values[path]);
    final value = Map<String, dynamic>.from(transaction.value! as Map)
      ..['anchorServerMs'] = DateTime.now().millisecondsSinceEpoch;
    database.values[path] = value;
    return _Result(true, value);
  }
}

class _Event extends Fake implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Snapshot(value);
  @override
  final DataSnapshot snapshot;
}

class _Snapshot extends Fake implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
}

class _Result extends Fake implements TransactionResult {
  _Result(this.committed, Object? value) : snapshot = _Snapshot(value);
  @override
  final bool committed;
  @override
  final DataSnapshot snapshot;
}
