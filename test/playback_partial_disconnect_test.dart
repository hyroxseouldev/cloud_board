import 'dart:async';

import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/playback_recovery_fixture.dart';

void main() {
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
