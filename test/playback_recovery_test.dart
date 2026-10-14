import 'dart:async';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';

import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';

import 'support/playback_recovery_fixture.dart';

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
  for (final stalledPath in ['activeSession', 'playbackSnapshots']) {
    testWidgets(
      'recovery bounds a stalled $stalledPath REST read to eight seconds',
      (tester) async {
        final db = _Database(session());
        final pending = Completer<Object?>();
        final source = PlaybackRealtimeDataSource(
          db,
          'u',
          serverRead: (path) {
            if (stalledPath == 'activeSession' ||
                path.contains('/playbackSnapshots/')) {
              return pending.future;
            }
            return Future.value({
              ...session(),
              'schemaVersion': 2,
              'snapshotId': 's',
            });
          },
        );
        final failure = expectLater(
          source.recover(restartTransport: false),
          throwsA(isA<TimeoutException>()),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 8));
        await failure;
        await source.dispose();
        await db.events.close();
      },
    );
  }
  testWidgets('automatic manual and remote callers join one actual handshake', (
    tester,
  ) async {
    final actions = _BarrierActions();
    final container = ProviderContainer(
      overrides: [
        playbackActionsProvider.overrideWith((_) => actions),
        activePlaybackSessionProvider.overrideWith((_) => Stream.value(null)),
        serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
      ],
    );
    final controller = container.read(
      playbackRecoveryControllerProvider.notifier,
    );
    final first = controller.recover(restartTransport: false);
    var manualDone = false;
    final manual = controller.recover().then((_) => manualDone = true);
    final remote = controller.recoverConfirmed();
    await tester.pump();
    expect(actions.pending.length, 1);
    expect(
      manualDone,
      isFalse,
      reason: 'A joined request must wait for real server confirmation',
    );
    actions.pending.single.complete();
    await tester.pump();
    await first;
    await manual;
    expect(await remote, isTrue);
    expect(actions.pending.length, 1);
    container.dispose();
  });

  testWidgets(
    'background/account cancellation ignores late result and serializes next generation',
    (tester) async {
      final actions = _BarrierActions();
      final container = ProviderContainer(
        overrides: [
          playbackActionsProvider.overrideWith((_) => actions),
          activePlaybackSessionProvider.overrideWith((_) => Stream.value(null)),
          serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
        ],
      );
      final controller = container.read(
        playbackRecoveryControllerProvider.notifier,
      );
      final old = controller.recoverConfirmed();
      controller.suspend();
      final current = controller.recoverConfirmed();
      expect(actions.pending.length, 1);
      actions.pending.first.complete();
      await tester.pump();
      expect(await old, isFalse);
      expect(actions.pending.length, 2);
      expect(
        container.read(playbackRecoveryControllerProvider).isLoading,
        isTrue,
      );
      actions.pending.last.complete();
      await tester.pump();
      expect(await current, isTrue);
      container.dispose();
    },
  );

  test(
    'confirmed completed session survives stale cached resubscription',
    () async {
      final db = _Database(session());
      final source = PlaybackRealtimeDataSource(
        db,
        'u',
        serverRead: (_) async => session(revision: 9, status: 'completed'),
      );
      await source.recover(restartTransport: false);
      final seen = <PlaybackSessionModel?>[];
      final subscription = source.watchActive().listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      expect(seen.single?.status, 'completed');
      expect(seen.single?.revision, 9);
      db.events.add(_Event(session(revision: 2)));
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, 1);
      await subscription.cancel();
      await source.dispose();
      await db.events.close();
    },
  );

  test('repository forwards contradiction read errors', () async {
    final db = RecoveryDatabase(null);
    var fail = false;
    final source = PlaybackRealtimeDataSource(
      db,
      'owner',
      serverRead: (_) async {
        if (fail) throw StateError('offline');
        return recoverySession();
      },
    );
    final repository = PlaybackRepositoryImpl(source, RecoveryCache(), 'owner');
    await repository.recover(restartTransport: false);
    fail = true;
    final error = Completer<Object>();
    final sub = repository.watchActive().listen(
      (_) {},
      onError: error.complete,
    );
    expect(
      await error.future.timeout(const Duration(seconds: 1)),
      isStateError,
    );
    await sub.cancel();
    await source.dispose();
    await db.events.close();
  });

  // This controller/data test uses the real event loop: SDK stream cancellation
  // Futures are part of the error contract, not widget rendering/fake time.
  test(
    'contradictory confirmation failure stays blocked until explicit retry',
    () async {
      final h = RecoveryHarness(recoverySession());
      addTearDown(h.dispose);
      await Future<void>.delayed(Duration.zero);
      h.db.cached = null;
      var reads = 0;
      final response = Completer<void>();
      final fresh = recoverySession(revision: 5, status: 'paused');
      h.readServer = () async {
        if (++reads == 1) return fresh;
        // Release an asynchronous read, then fail where a network call fails.
        await response.future;
        throw StateError('confirmation offline');
      };
      final recovering = h.recovery.recover();
      await Future<void>.delayed(Duration.zero);
      expect(reads, 2);
      expect(
        h.container.read(playbackRecoveryControllerProvider).isLoading,
        isTrue,
      );
      expect(await h.commands.resume(), isFalse);
      response.complete();
      await Future<void>.delayed(Duration.zero);

      await recovering.timeout(const Duration(seconds: 2));
      expect(
        h.container.read(playbackRecoveryControllerProvider).hasError,
        isTrue,
      );
      expect(h.container.read(activePlaybackSessionProvider).hasError, isTrue);
      expect(await h.commands.resume(), isFalse);
      expect(h.db.transactions, 0);
      h.readServer = () async => fresh;
      final retry = h.recovery.recover();
      await Future<void>.delayed(Duration.zero);
      await retry.timeout(const Duration(seconds: 2));
      expect(
        h.container.read(playbackRecoveryControllerProvider).hasValue,
        isTrue,
      );
      expect(
        h.container.read(activePlaybackSessionProvider).value?.revision,
        5,
      );
      await h.dispose();
      await Future<void>.delayed(Duration.zero);
    },
  );

  for (final originallyPresent in [false, true]) {
    for (final nowPresent in [false, true]) {
      test(
        'first SDK contradiction confirms presence $originallyPresent -> $nowPresent',
        () async {
          final db = RecoveryDatabase(
            originallyPresent ? null : recoverySession(),
          );
          Object? server = originallyPresent
              ? recoverySession(revision: 3)
              : null;
          var reads = 0;
          final source = PlaybackRealtimeDataSource(
            db,
            'owner',
            serverRead: (_) async {
              reads++;
              return server;
            },
          );
          await source.recover(restartTransport: false);
          server = nowPresent
              ? recoverySession(
                  id: originallyPresent ? 'class' : 'new-class',
                  revision: 4,
                )
              : null;
          final seen = <PlaybackSessionModel?>[];
          final sub = source.watchActive().listen(seen.add);
          await Future<void>.delayed(Duration.zero);
          expect(reads, 2);
          expect(
            seen,
            hasLength(1),
            reason: 'Contradiction must be verified before readiness',
          );
          expect(
            seen.last?.id,
            nowPresent
                ? originallyPresent
                      ? 'class'
                      : 'new-class'
                : null,
          );
          expect(db.writes, 0);
          await sub.cancel();
          await source.dispose();
          await db.events.close();
        },
      );
    }
  }

  test('failed contradictory SDK confirmation exposes the error', () async {
    final db = RecoveryDatabase(null);
    var fail = false;
    final failure = StateError('server unavailable');
    final source = PlaybackRealtimeDataSource(
      db,
      'owner',
      serverRead: (_) async {
        if (fail) throw failure;
        return recoverySession(revision: 3);
      },
    );
    await source.recover(restartTransport: false);
    fail = true;
    final errors = <Object>[];
    final sub = source.watchActive().listen((_) {}, onError: errors.add);
    await Future<void>.delayed(Duration.zero);
    expect(errors, [failure]);
    await sub.cancel();
    await source.dispose();
    await db.events.close();
  });

  for (final boundary in [
    'recovery',
    'sdk',
    'duplicate',
    'dispose',
    'late-error',
  ]) {
    test('late contradictory read cannot undo $boundary', () async {
      final initial = recoverySession(revision: 3);
      final db = RecoveryDatabase(initial);
      Future<Object?> Function() read = () async => initial;
      final source = PlaybackRealtimeDataSource(
        db,
        'owner',
        serverRead: (_) => read(),
      );
      await source.recover(restartTransport: false);
      final oldSub = source.watchActive().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      db.cached = null;
      final delayed = Completer<Object?>();
      read = () => delayed.future;
      final seen = <PlaybackSessionModel?>[];
      final errors = <Object>[];
      final sub = source.watchActive().listen(seen.add, onError: errors.add);
      await Future<void>.delayed(Duration.zero);
      final next = recoverySession(
        id: 'new-class',
        revision: 1,
        anchor: DateTime.now().millisecondsSinceEpoch,
      );
      if (boundary == 'recovery') {
        read = () async => next;
        await source.recover(restartTransport: false);
      } else if (boundary == 'sdk' ||
          boundary == 'duplicate' ||
          boundary == 'late-error') {
        db.deliver(boundary == 'duplicate' ? initial : next);
        await Future<void>.delayed(Duration.zero);
      } else {
        await source.dispose();
      }
      if (boundary == 'late-error') {
        delayed.completeError(StateError('obsolete read failed'));
      } else {
        delayed.complete(null);
      }
      await Future<void>.delayed(Duration.zero);
      if (boundary == 'dispose') {
        expect(seen, isEmpty);
      } else {
        expect(seen.last?.id, boundary == 'duplicate' ? null : 'new-class');
      }
      expect(errors, isEmpty);
      await oldSub.cancel();
      await sub.cancel();
      if (boundary != 'dispose') await source.dispose();
      expect(
        await source.watchActive().toList(),
        isEmpty,
        reason: 'Disposed owner must not replay',
      );
      await db.events.close();
    });
  }

  test(
    'anonymous TV can replay verified owner state without controller auth',
    () async {
      final db = RecoveryDatabase(recoverySession());
      final source = PlaybackRealtimeDataSource(
        db,
        'owner',
        isCurrentAccount: () => false,
        serverRead: (_) async => recoverySession(revision: 4),
      );
      await source.recover(restartTransport: false);
      expect((await source.watchActive().first)?.revision, 4);
      await source.dispose();
      await db.events.close();
    },
  );

  for (final deleted in [false, true]) {
    testWidgets(
      'verified ${deleted ? 'deletion' : 'revision'} survives real recovery provider resubscribe',
      (tester) async {
        final h = RecoveryHarness(recoverySession());
        addTearDown(h.dispose);
        await tester.pump();
        expect(
          h.container.read(activePlaybackSessionProvider).value?.revision,
          1,
        );
        final response = Completer<Object?>();
        h.readServer = () => response.future;
        h.recovery.suspend();
        final recovering = h.recovery.recover();
        await tester.pump();
        expect(
          h.container.read(playbackRecoveryControllerProvider).isLoading,
          isTrue,
        );
        final fresh = deleted
            ? null
            : recoverySession(revision: 4, status: 'paused');
        response.complete(fresh);
        await tester.pump();
        await tester.pump(const Duration(seconds: 7));
        await recovering;
        expect(
          h.container.read(playbackRecoveryControllerProvider).hasValue,
          isTrue,
        );
        final active = h.container.read(activePlaybackSessionProvider);
        expect(active.isLoading, isFalse);
        expect(active.value?.revision, deleted ? null : 4);
        expect(h.cache.value?.revision, deleted ? null : 4);
        expect(
          h.db.writes,
          0,
          reason: 'Recovery must never restart or change the class',
        );
        expect(h.restReads, 1);
      },
    );
  }

  for (final update in ['revision', 'replacement', 'deletion']) {
    test(
      'resubscribe retains accepted $update after REST verification',
      () async {
        final db = _Database(session());
        final source = PlaybackRealtimeDataSource(
          db,
          'u',
          serverRead: (_) async => session(revision: 3),
        );
        final seen = <PlaybackSessionModel?>[];
        var sub = source.watchActive().listen(seen.add);
        await Future<void>.delayed(Duration.zero);
        await source.recover(restartTransport: false);
        final next = update == 'deletion'
            ? null
            : {
                ...session(revision: update == 'replacement' ? 1 : 4),
                if (update == 'replacement') 'id': 'replacement',
                if (update == 'replacement') 'anchorServerMs': 100,
              };
        db.events.add(_Event(next));
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        seen.clear();
        sub = source.watchActive().listen(seen.add);
        await Future<void>.delayed(Duration.zero);
        expect(seen, isNotEmpty);
        expect(
          seen.first?.id,
          update == 'deletion'
              ? null
              : update == 'replacement'
              ? 'replacement'
              : 's',
        );
        expect(
          seen.last?.revision,
          update == 'deletion'
              ? null
              : update == 'replacement'
              ? 1
              : 4,
        );
        await sub.cancel();
        await source.dispose();
        await db.events.close();
      },
    );
  }

  test('filtered stale decode cannot replace the deletion tombstone', () async {
    final db = _Database(session());
    Object? response = {
      ...session(revision: 3),
      'id': 'new',
      'anchorServerMs': 100,
    };
    final source = PlaybackRealtimeDataSource(
      db,
      'u',
      serverRead: (_) async => response,
    );
    final seen = <PlaybackSessionModel?>[];
    final sub = source.watchActive().listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    await source.recover(restartTransport: false);
    db.events.add(_Event(session()));
    await Future<void>.delayed(Duration.zero);
    response = null;
    await source.recover(restartTransport: false);
    db.events.add(
      _Event({...session(revision: 3), 'id': 'new', 'anchorServerMs': 100}),
    );
    await Future<void>.delayed(Duration.zero);
    expect(seen.last, isNull);
    await sub.cancel();
    await source.dispose();
    await db.events.close();
  });

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
      expect(seen, [null]);
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
          accountOwnerIdProvider.overrideWith((_) => Stream.value('owner')),
          firebaseAccountUserProvider.overrideWith(
            (_) => Stream.value(RecoveryUser('owner')),
          ),
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
      container.listen(accountOwnerIdProvider, (_, _) {});
      container.listen(firebaseAccountUserProvider, (_, _) {});
      await tester.pump();
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

class _BarrierActions extends Fake implements PlaybackActions {
  final pending = <Completer<void>>[];
  @override
  Future<void> recover({required bool restartTransport}) {
    final completer = Completer<void>();
    pending.add(completer);
    return completer.future;
  }
}
