import 'dart:async';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/operations/data/operation_event_writer.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/operation_event_recorder.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/usecases/playback_actions.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/playback_recovery_fixture.dart';

void main() {
  testWidgets(
    'account change separates completion flights and late completion cannot clear the new flight',
    (tester) async {
      final h = _CompletionHarness();
      addTearDown(h.close);
      await tester.pump();
      final first = h.commands.complete();
      await tester.pump();
      expect(h.first.pending, hasLength(1));
      h.scope.owners.add('other-owner');
      h.scope.users.add(RecoveryUser('other-owner'));
      await tester.pump();
      expect(
        await h.commands.complete(),
        isFalse,
        reason: 'The previous owner session cannot control the new owner',
      );
      h.container.invalidate(activePlaybackSessionProvider);
      h.container.read(activePlaybackSessionProvider);
      expect(
        await h.commands.complete(),
        isFalse,
        reason: 'A refreshing stream cannot submit its retained session',
      );
      await tester.pump();
      h.sessions.addError(StateError('session unavailable'));
      await tester.pump();
      expect(await h.commands.complete(), isFalse);
      expect(h.second.pending, isEmpty);
      h.sessions.add(_CompletionHarness.session('other-owner'));
      await tester.pump();
      expect(
        h.container.read(activePlaybackSessionProvider).value!.ownerId,
        'other-owner',
      );
      final second = h.commands.complete();
      await tester.pump();
      expect(h.second.pending, hasLength(1));
      expect(identical(first, second), isFalse);
      expect(identical(second, h.commands.complete()), isTrue);
      h.first.pending.single.complete();
      await tester.pump();
      expect(await first, isTrue);
      expect(
        h.container.read(playbackActionControllerProvider).isLoading,
        isTrue,
      );
      expect(identical(second, h.commands.complete()), isTrue);
      h.second.pending.single.complete();
      await tester.pump();
      expect(await second, isTrue);
      expect(h.first.pending, hasLength(1));
      expect(h.second.pending, hasLength(1));
      expect(h.events, isEmpty);
      await h.close();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  for (final boundary in [
    'owner-change',
    'owner-return',
    'owner-loading',
    'owner-error',
    'owner-null',
    'auth-change',
    'auth-return',
    'auth-loading',
    'auth-error',
    'auth-null',
  ]) {
    for (final failed in [false, true]) {
      testWidgets(
        'late transport ${failed ? 'failure' : 'success'} after $boundary cannot change current UI or operational history',
        (tester) async {
          final scope = _AccountStreams();
          final h = scope.create();
          addTearDown(() async {
            await h.dispose();
            await scope.close();
          });
          await tester.pump();
          final gate = Completer<void>();
          h.db.beforeTransaction = () async {
            await gate.future;
            if (failed) throw StateError('late transport failure');
          };
          final result = h.commands.pause(55000);
          await tester.pump();
          expect(h.db.transactions, 1);
          await scope.cross(boundary, h.container, tester);
          gate.complete();
          await tester.pump();
          expect(
            await result,
            !failed,
            reason: 'A committed command stays successful',
          );
          final state = h.container.read(playbackActionControllerProvider);
          expect(state.isLoading, isFalse);
          expect(state.hasError, isFalse);
          expect(
            state.value,
            isNull,
            reason: 'Old results cannot label the new scope',
          );
          await tester.pump(const Duration(seconds: 13));
          expect(h.operationEvents, isEmpty);
          expect(
            h.db.transactions,
            1,
            reason: 'An account change never replays a command',
          );
          expect(h.db.writes, failed ? 0 : 1);
        },
      );
    }
    testWidgets(
      'pending TV acknowledgement after $boundary cannot record a timeout for another account',
      (tester) async {
        final scope = _AccountStreams();
        final h = scope.create();
        addTearDown(() async {
          await h.dispose();
          await scope.close();
        });
        await tester.pump();
        expect(await h.commands.pause(55000), isTrue);
        await tester.pump();
        // Leave session/devices unchanged to model delayed new account streams.
        await scope.cross(boundary, h.container, tester);
        await tester.pump(const Duration(seconds: 13));
        expect(h.operationEvents, isEmpty);
        expect(h.db.transactions, 1);
      },
    );
  }

  for (final received in [false, true]) {
    testWidgets(
      'same account TV acknowledgement ${received ? 'success' : 'timeout'} retains operational evidence',
      (tester) async {
        final h = RecoveryHarness(recoverySession());
        addTearDown(h.dispose);
        await tester.pump();
        expect(await h.commands.pause(55000), isTrue);
        await tester.pump();
        h.acknowledgeHealthyTvs();
        if (received) {
          h.devices = h.devices
              .map(
                (device) => DisplayDevice(
                  id: device.id,
                  name: device.name,
                  zoneId: device.zoneId,
                  zoneName: device.zoneName,
                  online: true,
                  lastSeenAtMs: device.lastSeenAtMs,
                  currentSessionId: device.currentSessionId,
                  acknowledgedRevision: 2,
                  paired: true,
                ),
              )
              .toList();
          h.deviceEvents.add(h.devices);
        }
        await tester.pump();
        if (!received) await tester.pump(const Duration(seconds: 13));
        expect(h.operationEvents, hasLength(3));
        expect(
          h.operationEvents.every((entry) => entry.ownerId == 'owner'),
          isTrue,
        );
        expect(
          h.operationEvents.where(
            (entry) => entry.event.type == 'command_received',
          ),
          hasLength(received ? 3 : 2),
        );
        expect(
          h.operationEvents.where(
            (entry) => entry.event.type == 'command_receipt_failed',
          ),
          hasLength(received ? 0 : 1),
        );
        await tester.pump(const Duration(milliseconds: 350));
      },
    );
  }

  testWidgets('one missing TV ACK never blocks real pause resume or seek', (
    tester,
  ) async {
    final h = RecoveryHarness(recoverySession());
    addTearDown(h.dispose);
    await tester.pump();
    h.acknowledgeHealthyTvs();
    await tester.pump();
    final initial = h.container.read(activePlaybackSessionProvider).value!;
    expect(initial.targetDeviceIds, recoveryTargets);
    expect(await h.commands.pause(55000), isTrue);
    await tester.pump();
    h.acknowledgeHealthyTvs();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      h.container.read(activePlaybackSessionProvider).value?.status,
      PlaybackStatus.paused,
    );
    // Resume before the preceding ACK observer's 12 second deadline.
    expect(await h.commands.resume(), isTrue);
    await tester.pump();
    h.acknowledgeHealthyTvs();
    await tester.pump(const Duration(milliseconds: 350));
    expect(await h.commands.seek(stepIndex: 1, durationMs: 90000), isTrue);
    await tester.pump();
    h.acknowledgeHealthyTvs();
    await tester.pump(const Duration(seconds: 13));
    final current = h.container.read(activePlaybackSessionProvider).value!;
    expect(current.id, initial.id);
    expect(current.revision, 4);
    expect(current.stepIndex, 1);
    expect(current.status, PlaybackStatus.playing);
    expect(current.targetDeviceIds, recoveryTargets);
    expect(h.db.transactions, 3);
    expect(h.db.writes, 3);
    expect(
      h.restReads,
      0,
      reason: 'Missing TV ACK does not force phone recovery',
    );
    expect(
      h.container.read(playbackRecoveryControllerProvider).hasValue,
      isTrue,
    );
    expect(
      h.container.read(playbackActionControllerProvider).hasError,
      isFalse,
    );
    await h.telemetry.flush();
    expect(
      h.events.where(
        (e) =>
            e['action'] == 'playback.control.submit' &&
            e['outcome'] == 'success',
      ),
      hasLength(3),
    );
    expect(
      h.events.where(
        (e) => e['action'] == 'playback.control.ack' && e['code'] == 'timeout',
      ),
      hasLength(1),
    );
    expect(h.devices.last.acknowledgedRevision, 1);
    expect(h.devices.take(2).every((d) => d.acknowledgedRevision == 4), isTrue);
    // Even a completed ACK timeout is passive: a subsequent user tap works.
    expect(await h.commands.pause(89000), isTrue);
    await tester.pump();
    expect(h.db.transactions, 4);
    await h.dispose();
    await tester.pump();
  });

  testWidgets(
    'phone suspend delayed server failure and retry restore the latest class without reset',
    (tester) async {
      final h = RecoveryHarness(recoverySession());
      addTearDown(h.dispose);
      await tester.pump();
      final running = h.container.read(activePlaybackSessionProvider).value!;
      final tvPosition = playbackPosition(
        running,
        playbackDurations(running.workout),
        running.anchorServerMs + 9000,
      );
      final response = Completer<Object?>();
      h.readServer = () => response.future;
      h.recovery.suspend();
      expect(await h.commands.pause(50000), isFalse);
      final recovery = h.recovery.recover();
      await tester.pump(const Duration(seconds: 2));
      expect(await h.commands.resume(), isFalse);
      expect(h.db.writes, 0);
      expect(
        playbackPosition(
          running,
          playbackDurations(running.workout),
          running.anchorServerMs + 11000,
        ).remainingMs,
        tvPosition.remainingMs - 2000,
      );
      response.completeError(StateError('server delayed / unavailable'));
      await tester.pump();
      await recovery;
      expect(
        h.container.read(playbackRecoveryControllerProvider).hasError,
        isTrue,
      );
      expect(await h.commands.seek(stepIndex: 1, durationMs: 90000), isFalse);
      final latest = {
        ...recoverySession(revision: 7, status: 'paused'),
        'stepIndex': 1,
        'remainingMs': 42000,
        'workoutSnapshot': (h.db.server! as Map)['workoutSnapshot'],
      };
      h.db.server = latest;
      h.readServer = () async => latest;
      final retry = h.recovery.recover();
      await tester.pump();
      await retry;
      final restored = h.container.read(activePlaybackSessionProvider).value!;
      expect(restored.id, running.id);
      expect(restored.revision, 7);
      expect(restored.stepIndex, 1);
      expect(restored.remainingMs, 42000);
      expect(restored.anchorServerMs, latest['anchorServerMs']);
      expect(restored.workout, running.workout);
      expect(h.db.writes, 0);
      expect(h.db.transactions, 0);
      expect(h.db.transport, ['offline', 'online', 'offline', 'online']);
      expect(await h.commands.resume(), isTrue);
      await tester.pump();
      final resumed = h.container.read(activePlaybackSessionProvider).value!;
      expect(resumed.revision, 8);
      expect(resumed.remainingMs, 42000);
      expect(resumed.stepIndex, 1);
      expect(
        h.db.transactions,
        1,
        reason: 'Only the new explicit user intent is submitted',
      );
      await h.dispose();
      await tester.pump();
    },
  );

  for (final rejection in ['revision_conflict', 'command_expired']) {
    testWidgets(
      '$rejection refreshes latest state without replaying an old seek',
      (tester) async {
        final h = RecoveryHarness(recoverySession());
        addTearDown(h.dispose);
        await tester.pump();
        final before = h.container.read(activePlaybackSessionProvider).value!;
        // The transport reports a rejection after another controller has moved on.
        // Expiry enforcement itself is exercised in command/protocol/rules suites.
        h.db.beforeTransaction = () async {
          h.db.server = {
            ...recoverySession(revision: 9, status: 'paused'),
            'stepIndex': 1,
            'remainingMs': 27000,
          };
          if (rejection == 'command_expired') {
            throw const PlaybackFailure('command_expired', 'expired');
          }
        };
        final seek = h.commands.seek(stepIndex: 0, durationMs: 60000);
        await tester.pump();
        expect(await seek, isFalse);
        expect(h.db.transactions, 1);
        expect(h.db.writes, 0);
        expect(h.restReads, 1);
        final restored = h.container.read(activePlaybackSessionProvider).value!;
        expect(restored.id, before.id);
        expect(restored.revision, 9);
        expect(restored.stepIndex, 1);
        expect(restored.remainingMs, 27000);
        expect(
          h.container.read(playbackRecoveryControllerProvider).hasValue,
          isTrue,
        );
        await tester.pump(const Duration(seconds: 15));
        expect(
          h.db.transactions,
          1,
          reason: 'Recovery must not replay the expired/obsolete command',
        );
        h.db.beforeTransaction = null;
        expect(await h.commands.resume(), isTrue);
        await tester.pump();
        expect(h.db.transactions, 2);
        expect(h.db.writes, 1);
        expect(
          h.container.read(activePlaybackSessionProvider).value?.stepIndex,
          1,
        );
        await h.dispose();
        await tester.pump();
      },
    );
  }
}

class _CompletionActions extends Fake implements PlaybackActions {
  final pending = <Completer<void>>[];
  @override
  Future<void> complete({required String deviceId}) {
    final next = Completer<void>();
    pending.add(next);
    return next.future;
  }
}

class _AccountStreams {
  final owners = StreamController<String?>.broadcast(sync: true);
  final users = StreamController<User?>.broadcast(sync: true);
  RecoveryHarness create() => RecoveryHarness(
    recoverySession(),
    owners: ownerStream(),
    users: userStream(),
  );
  Stream<String?> ownerStream() => Stream.multi((sink) {
    sink.add('owner');
    final sub = owners.stream.listen(sink.add, onError: sink.addError);
    sink.onCancel = sub.cancel;
  });
  Stream<User?> userStream() => Stream.multi((sink) {
    sink.add(RecoveryUser('owner'));
    final sub = users.stream.listen(sink.add, onError: sink.addError);
    sink.onCancel = sub.cancel;
  });

  Future<void> cross(
    String boundary,
    ProviderContainer container,
    WidgetTester tester,
  ) async {
    final owner = boundary.startsWith('owner');
    final kind = boundary.split('-').last;
    if (kind == 'loading') {
      container.invalidate(
        owner ? accountOwnerIdProvider : firebaseAccountUserProvider,
      );
      // Observe the loading transition before the replayed value resolves.
      container.read(
        owner ? accountOwnerIdProvider : firebaseAccountUserProvider,
      );
    } else if (owner) {
      if (kind == 'error') {
        owners.addError(StateError('owner unavailable'));
      } else {
        owners.add(kind == 'null' ? null : 'other-owner');
      }
    } else {
      if (kind == 'error') {
        users.addError(StateError('auth unavailable'));
      } else {
        users.add(kind == 'null' ? null : RecoveryUser('other-user'));
      }
    }
    await tester.pump();
    if (kind == 'return') {
      if (owner) {
        owners.add('owner');
      } else {
        users.add(RecoveryUser('owner'));
      }
      await tester.pump();
    }
  }

  Future<void> close() async {
    await owners.close();
    await users.close();
  }
}

class _CompletionHarness {
  final scope = _AccountStreams();
  final first = _CompletionActions(), second = _CompletionActions();
  final sessions = StreamController<PlaybackSession?>.broadcast(sync: true);
  final events = <OperationEvent>[];
  static PlaybackSession session(String owner) {
    final value = recoverySession(id: 'class-$owner');
    final workout = Map<String, dynamic>.from(value['workoutSnapshot'] as Map);
    workout['id'] = 'workout-$owner';
    workout['ownerId'] = owner;
    workout['author'] = <String, dynamic>{
      ...Map<String, dynamic>.from(workout['author'] as Map),
      'id': owner,
    };
    return PlaybackSessionModel.fromJson({
      ...value,
      'ownerId': owner,
      'workoutSnapshot': workout,
    }).toEntity();
  }

  late final container =
      ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            accountOwnerIdProvider.overrideWith((_) => scope.ownerStream()),
            firebaseAccountUserProvider.overrideWith((_) => scope.userStream()),
            activePlaybackSessionProvider.overrideWith(
              (_) => Stream.multi((sink) {
                sink.add(session('owner'));
                final sub = sessions.stream.listen(
                  sink.add,
                  onError: sink.addError,
                );
                sink.onCancel = sub.cancel;
              }),
            ),
            playbackActionsProvider.overrideWith(
              (ref) => ref.watch(accountOwnerIdProvider).value == 'owner'
                  ? first
                  : second,
            ),
            deviceIdProvider.overrideWith((_) async => 'phone'),
            displayDevicesProvider.overrideWith((_) => Stream.value([])),
            playbackConnectionProvider.overrideWith((_) => Stream.value(true)),
            serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
            operationEventWriterProvider.overrideWith((ref) {
              final writer = OperationEventWriter(
                (event) async => events.add(event),
              );
              ref.onDispose(writer.dispose);
              return writer;
            }),
          ],
        )
        ..listen(accountOwnerIdProvider, (_, _) {})
        ..listen(firebaseAccountUserProvider, (_, _) {})
        ..listen(activePlaybackSessionProvider, (_, _) {});
  PlaybackActionController get commands =>
      container.read(playbackActionControllerProvider.notifier);
  _CompletionHarness() {
    container;
  }
  bool disposed = false;
  Future<void> close() async {
    if (disposed) return;
    disposed = true;
    container.dispose();
    await scope.close();
    await sessions.close();
  }
}
