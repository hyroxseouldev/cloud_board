import 'dart:async';

import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/playback_recovery_fixture.dart';

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

  tearDown(() => source.dispose());

  test('slow telemetry cannot delay an acknowledged class start', () async {
    final pending = Completer<void>();
    database.eventGate = pending.future;
    final started = await source
        .start(model)
        .timeout(const Duration(seconds: 1));
    expect(started.id, 'class');
    expect(pending.isCompleted, isFalse);
    pending.complete();
    await database.firstEventWritten.future.timeout(const Duration(seconds: 1));
    expect(
      database.values['users/coach/operations/events/class-started'],
      isNotNull,
    );
  });

  test(
    'class starts and pauses when metadata get is denied but SDK events work',
    () async {
      final started = await source.start(model);
      expect(started.id, 'class');
      await database.firstEventWritten.future.timeout(
        const Duration(seconds: 1),
      );
      expect(database.writes, 2); // Display update and independent telemetry.
      final recorded =
          database.values['users/coach/operations/events/class-started'] as Map;
      expect(recorded['sessionId'], 'class');
      expect(recorded['phase'], 'server_approval');
      expect(recorded['eventId'], 'class-started');
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
      expect(database.transactions, 2);
    },
  );

  test(
    'recovery transport records telemetry separately from playback writes',
    () async {
      final recoveryDb = RecoveryDatabase(recoverySession());
      final recoverySource = PlaybackRealtimeDataSource(recoveryDb, 'owner');
      addTearDown(() async {
        await recoverySource.dispose();
        await recoveryDb.events.close();
      });
      final paused = await recoverySource.update(
        status: 'paused',
        deviceId: 'phone',
        expectedSessionId: 'class',
        expectedRevision: 1,
      );
      expect(paused.status, 'paused');
      expect(recoveryDb.transactions, 1);
      expect(recoveryDb.writes, 1);
      expect(recoveryDb.operationEventWrites, 1);
      final event = recoveryDb.operationEvents.values.single;
      expect(
        recoveryDb.operationEvents.keys.single,
        'users/owner/operations/events/${event['eventId']}',
      );
      expect(event['sessionId'], 'class');
      expect(event['type'], 'command_approved');
      expect(event['phase'], 'server_approval');
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

  for (final boundary in [
    'active-read',
    'snapshot-write',
    'transaction-retry',
  ]) {
    test('cancelled start cannot commit after $boundary', () async {
      database.values['users/coach/devices'] = {
        'tv': {'paired': true, 'playbackProtocol': 2},
      };
      var current = true;
      final entered = Completer<void>();
      final release = Completer<void>();
      Future<void> pause() async {
        entered.complete();
        await release.future;
      }

      if (boundary == 'active-read') {
        database.beforeGet = (path) async {
          if (path.endsWith('/activeSession')) await pause();
        };
      } else if (boundary == 'snapshot-write') {
        database.beforeSet = (path) async {
          if (path.contains('/playbackSnapshots/')) await pause();
        };
      } else {
        database.beforeTransactionRetry = () => current = false;
      }
      final starting = source.start(
        model,
        ensureCurrent: () {
          if (!current) {
            throw const PlaybackFailure('start_cancelled', 'cancelled');
          }
        },
      );
      final rejected = expectLater(
        starting,
        throwsA(
          isA<PlaybackFailure>().having(
            (e) => e.code,
            'code',
            'start_cancelled',
          ),
        ),
      );
      if (boundary != 'transaction-retry') {
        await entered.future;
        current = false;
        release.complete();
      }
      await rejected;
      expect(database.values['users/coach/activeSession'], isNull);
      expect(
        database.values.keys.where(
          (path) => path.contains('/operations/events/'),
        ),
        isEmpty,
      );
      expect(database.transactions, boundary == 'transaction-retry' ? 1 : 0);
    });
  }

  test(
    'cancellation after acknowledged commit cannot turn start into failure',
    () async {
      var current = true;
      database.afterCommit = () => current = false;
      final started = await source.start(
        model,
        ensureCurrent: () {
          if (!current) {
            throw const PlaybackFailure('start_cancelled', 'cancelled');
          }
        },
      );
      expect(started.id, 'class');
      expect(database.values['users/coach/activeSession'], isNotNull);
      expect(database.transactions, 1);
    },
  );

  test(
    'account change after committed start skips ancillary writes and telemetry',
    () async {
      var current = true;
      source.dispose();
      source = PlaybackRealtimeDataSource(
        database,
        'coach',
        isCurrentAccount: () => current,
      );
      database.afterCommit = () => current = false;
      final started = await source.start(model);
      expect(started.id, 'class');
      expect(database.values['users/coach/activeSession'], isNotNull);
      expect(database.transactions, 1);
      expect(database.writes, 0);
      expect(
        database.values.keys.where(
          (path) => path.contains('/operations/events/'),
        ),
        isEmpty,
      );
    },
  );

  test('registration guard remains enforced after metadata fix', () async {
    database.values['users/coach/devices'] = {
      'tv': {'paired': false},
    };
    await expectLater(source.start(model), throwsStateError);
    expect(database.writes, 0);
  });

  test('For Time finish persists the frozen result, survives decode and clears on explicit seek', () async {
    final module = createContinuousTimer(
      WorkoutModule.empty('clock'),
      mode: WorkoutTimerMode.forTime,
      seconds: 0,
      direction: TimerDirection.up,
    );
    final clock = PlaybackSessionModel.fromWorkout(
      id: 'clock',
      ownerId: 'coach',
      zoneId: 'main',
      targetDeviceIds: ['tv'],
      workout: model.toEntity().workout.copyWith(
        modules: [module, WorkoutModule.empty('next')],
      ),
      stepIndex: 0,
      durationMs: 0,
      deviceId: 'controller',
    );
    await expectLater(source.start(clock), throwsA(isA<PlaybackFailure>()));
    database.values['users/coach/devices'] = {
      'tv': {'paired': true, 'playbackProtocol': 5},
    };
    final started = await source.start(clock);
    final wire = database.values['users/coach/activeSession'] as Map;
    wire['anchorServerMs'] = DateTime.now().millisecondsSinceEpoch - 7500;
    final finished = await source.update(
      status: 'paused',
      deviceId: 'controller',
      finishTimer: true,
      expectedSessionId: started.id,
      expectedRevision: started.revision,
    );
    expect(finished.timerCompleted, isTrue);
    expect(finished.status, 'paused');
    expect(finished.remainingMs, inInclusiveRange(7500, 8500));
    expect(
      PlaybackSessionModel.fromJson(finished.toJson())
          .toEntity()
          .timerCompleted,
      isTrue,
    );
    await expectLater(
      source.update(
        status: 'playing',
        deviceId: 'controller',
        expectedSessionId: finished.id,
        expectedRevision: finished.revision,
      ),
      throwsA(isA<PlaybackFailure>()),
    );
    final next = await source.update(
      status: null,
      deviceId: 'controller',
      stepIndex: 1,
      remainingMs: 60000,
      expectedSessionId: finished.id,
      expectedRevision: finished.revision,
    );
    expect(next.timerCompleted, isFalse);
    expect(next.status, 'playing');
    expect(next.stepIndex, 1);
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
  Future<void>? eventGate;
  final firstEventWritten = Completer<void>();
  Future<void> Function(String)? beforeGet, beforeSet;
  void Function()? beforeTransactionRetry, afterCommit;
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
    await database.beforeGet?.call(path);
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
  Future<void> set(Object? value) async {
    await database.beforeSet?.call(path);
    if (path.contains('/operations/events/') && database.eventGate != null) {
      await database.eventGate;
    }
    database.writes++;
    database.values[path] = value;
    if (path.contains('/operations/events/') &&
        !database.firstEventWritten.isCompleted) {
      database.firstEventWritten.complete();
    }
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
    var transaction = handler(database.values[path]);
    if (database.beforeTransactionRetry != null && !transaction.aborted) {
      database.beforeTransactionRetry!();
      transaction = handler(database.values[path]);
    }
    if (transaction.aborted) return _Result(false, database.values[path]);
    final value = Map<String, dynamic>.from(transaction.value! as Map)
      ..['anchorServerMs'] = DateTime.now().millisecondsSinceEpoch;
    database.values[path] = value;
    database.afterCommit?.call();
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
