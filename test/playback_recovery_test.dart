import 'dart:async';

import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/domain/usecases/playback_actions.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

Map<String, dynamic> session({int revision = 1, String status = 'playing'}) => {
  ...PlaybackSessionModel.fromWorkout(
    id: 's',
    ownerId: 'u',
    zoneId: 'main',
    targetDeviceIds: ['tv'],
    workout: Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(modules: [WorkoutModule.empty('m')]),
    stepIndex: 0,
    durationMs: 60000,
    deviceId: 'c',
  ).toJson(),
  'revision': revision,
  'status': status,
};

void main() {
  test(
    'resume confirms server state, rejects stale revisions, never writes',
    () async {
      final db = _Database(session());
      final response = Completer<Object?>();
      final source = PlaybackRealtimeDataSource(
        db,
        'u',
        serverRead: (_) => response.future,
      );
      final seen = <PlaybackSessionModel?>[];
      final subscription = source.watchActive().listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      final recovery = source.recover(restartTransport: true);
      await Future<void>.delayed(Duration.zero);
      db.events.add(_Event(session()));
      response.complete(session(revision: 3, status: 'paused'));
      await recovery;
      await Future<void>.delayed(Duration.zero);
      expect(db.transport, ['offline', 'online']);
      expect(seen.last?.status, 'paused');
      expect(seen.last?.revision, 3);
      final count = seen.length;
      db.events.add(_Event(session(revision: 2)));
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, count);
      db.events.add(_Event(session(revision: 4)));
      await Future<void>.delayed(Duration.zero);
      expect(seen.last?.revision, 4);
      await subscription.cancel();
      await source.dispose();
      await db.events.close();
    },
  );

  test(
    'server deletion does not resurrect cached class on resubscribe',
    () async {
      final db = _Database(session());
      final source = PlaybackRealtimeDataSource(
        db,
        'u',
        serverRead: (_) async => null,
      );
      final seen = <PlaybackSessionModel?>[];
      var subscription = source.watchActive().listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      await source.recover(restartTransport: true);
      await Future<void>.delayed(Duration.zero);
      expect(seen.last, isNull);
      await subscription.cancel();
      seen.clear();
      subscription = source.watchActive().listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      expect(seen.whereType<PlaybackSessionModel>(), isEmpty);
      await subscription.cancel();
      await source.dispose();
      await db.events.close();
    },
  );

  test('failed server read never reports cached state as recovered', () async {
    final db = _Database(session());
    final source = PlaybackRealtimeDataSource(
      db,
      'u',
      serverRead: (_) async => throw StateError('offline'),
    );
    await expectLater(source.recover(restartTransport: true), throwsStateError);
    await source.dispose();
    await db.events.close();
  });

  test('disposed account cannot complete an outstanding recovery', () async {
    final db = _Database(session());
    final response = Completer<Object?>();
    final source = PlaybackRealtimeDataSource(
      db,
      'u',
      serverRead: (_) => response.future,
    );
    final recovery = source.recover(restartTransport: true);
    final expectation = expectLater(recovery, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await source.dispose();
    response.complete(session());
    await expectation;
    await db.events.close();
  });

  testWidgets(
    'commands stay blocked on failure and recover after explicit retry',
    (tester) async {
      final actions = _Actions();
      final container = ProviderContainer(
        overrides: [
          playbackActionsProvider.overrideWith((ref) => actions),
          deviceIdProvider.overrideWith((ref) async => 'c'),
          activePlaybackSessionProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
        ],
      );
      final recovery = container.read(
        playbackRecoveryControllerProvider.notifier,
      );
      recovery.suspend();
      final commands = container.read(
        playbackActionControllerProvider.notifier,
      );
      expect(await commands.pause(1000), isFalse);
      expect(actions.pauses, 0);
      actions.fail = true;
      await recovery.recover();
      expect(
        container.read(playbackRecoveryControllerProvider).hasError,
        isTrue,
      );
      expect(await commands.pause(1000), isFalse);
      actions.fail = false;
      final pending = recovery.recover();
      await tester.pump();
      await pending;
      expect(
        container.read(playbackRecoveryControllerProvider).hasValue,
        isTrue,
      );
      expect(await commands.pause(1000), isTrue);
      expect(actions.pauses, 1);
      container.dispose();
    },
  );
}

class _Actions extends Fake implements PlaybackActions {
  bool fail = false;
  int pauses = 0;
  @override
  Future<void> recover({required bool restartTransport}) async {
    if (fail) throw StateError('offline');
  }

  @override
  Future<void> pause({
    required int remainingMs,
    required String deviceId,
  }) async {
    pauses++;
  }
}

class _Database extends Fake implements FirebaseDatabase {
  _Database(this.cached);
  final Object? cached;
  final events = StreamController<DatabaseEvent>.broadcast();
  final transport = <String>[];
  @override
  Future<void> goOffline() async {
    transport.add('offline');
  }

  @override
  Future<void> goOnline() async {
    transport.add('online');
  }

  @override
  DatabaseReference ref([String? path]) => _Reference(this, path!);
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.db, this.path);
  final _Database db;
  @override
  final String path;
  @override
  Stream<DatabaseEvent> get onValue => path == '.info/connected'
      ? Stream.value(_Event(true))
      : Stream.multi((sink) {
          sink.add(_Event(db.cached));
          final sub = db.events.stream.listen(sink.add);
          sink.onCancel = sub.cancel;
        });
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
