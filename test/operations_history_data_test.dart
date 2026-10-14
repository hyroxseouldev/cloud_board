import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/operations/data/datasources/store_operations_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/operations/data/operation_event_writer.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operation_history.dart';

void main() {
  const range = OperationEventRange(startAtMs: 1000, endBeforeMs: 5000);
  test('indexed range reads all 1501 rows without a hidden limit', () async {
    final db = _Database({
      for (var i = 0; i < 1501; i++)
        'e$i': {
          'type': 'playback_started',
          'occurredAtMs': 1000 + i,
          'sessionId': 's$i',
          'deviceId': 'controller',
        },
    });
    final rows = await StoreOperationsRealtimeDataSource(
      db,
      'center',
    ).watchEventsInRange(range).first;
    expect(rows.length, 1501);
    expect(db.requestedPath, 'users/center/operations/events');
    expect(db.order, 'occurredAtMs');
    expect(db.start, 1000);
    expect(db.end, 5000);
    expect(rows.first.id, 'e0');
  });

  test(
    'malformed stored row is query failure, never a complete zero',
    () async {
      final db = _Database({'broken': 'invalid'});
      await expectLater(
        StoreOperationsRealtimeDataSource(
          db,
          'center',
        ).watchEventsInRange(range),
        emitsError(isA<FormatException>()),
      );
    },
  );

  test(
    'unresolved owner is unavailable rather than no recorded classes',
    () async {
      final db = _Database(null);
      await expectLater(
        StoreOperationsRealtimeDataSource(db, null).watchEventsInRange(range),
        emitsError(isA<StateError>()),
      );
      expect(db.requestedPath, isNull);
    },
  );

  test(
    'retry uses identical ID, timestamp and deduplicates concurrent callers',
    () async {
      final writes = <OperationEvent>[];
      final first = Completer<void>();
      final writer = OperationEventWriter((event) async {
        writes.add(event);
        if (writes.length == 1) {
          await first.future;
          throw StateError('offline');
        }
      }, retryDelay: Duration.zero);
      const event = OperationEvent(
        id: 'fixed',
        eventId: 'fixed',
        type: 'command_failed',
        occurredAtMs: 1234,
        deviceId: 'phone',
        workoutId: 'w',
        workoutName: '수업',
        scheduled: false,
        scheduledAtMs: null,
      );
      final a = writer.record(event);
      final b = writer.record(event);
      expect(identical(a, b), isTrue);
      first.complete();
      await a;
      expect(writes.length, 2);
      expect(writes.every((row) => identical(row, event)), isTrue);
      writer.dispose();
    },
  );

  test(
    'permanent recording failure is swallowed after bounded retries',
    () async {
      var writes = 0;
      final writer = OperationEventWriter((event) async {
        writes++;
        throw StateError('permission denied');
      }, retryDelay: Duration.zero);
      await writer.record(
        const OperationEvent(
          id: 'fail',
          type: 'playback_started',
          occurredAtMs: 1,
          deviceId: null,
          workoutId: null,
          workoutName: null,
          scheduled: false,
          scheduledAtMs: null,
        ),
      );
      expect(writes, 3);
      writer.dispose();
    },
  );
}

class _Database extends Fake implements FirebaseDatabase {
  _Database(this.rows);
  final Object? rows;
  String? requestedPath, order;
  Object? start, end;
  @override
  DatabaseReference ref([String? path]) => _Reference(this, path ?? '');
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.db, this.path);
  final _Database db;
  @override
  final String path;
  @override
  DatabaseReference child(String path) => _Reference(db, '${this.path}/$path');
  @override
  Query orderByChild(String path) {
    db.order = path;
    return this;
  }

  @override
  Query startAt(Object? value, {String? key}) {
    db.start = value;
    return this;
  }

  @override
  Query endBefore(Object? value, {String? key}) {
    db.end = value;
    return this;
  }

  @override
  Stream<DatabaseEvent> get onValue {
    db.requestedPath = path;
    return Stream.value(_Event(db.rows));
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
