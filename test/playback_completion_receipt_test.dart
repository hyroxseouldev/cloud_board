import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

import 'support/playback_recovery_fixture.dart';

void main() {
  for (final automatic in [false, true]) {
    for (final delayedStream in [false, true]) {
      testWidgets(
        '${automatic ? 'natural' : 'manual'} completion never awaits a TV receipt (delayed stream: $delayedStream)',
        (tester) async {
          final h = RecoveryHarness(recoverySession());
          addTearDown(h.dispose);
          await tester.pump();
          h.db.publishTransactions = !delayedStream;
          expect(
            await (automatic
                ? h.commands.syncComplete()
                : h.commands.complete()),
            isTrue,
          );
          await tester.pump(const Duration(seconds: 15));
          expect((h.db.server as Map)['status'], 'completed');
          expect(
            h.container.read(playbackActionControllerProvider).hasError,
            isFalse,
          );
          expect(h.operationEvents, isEmpty);
          expect(
            h.db.operationEvents.values.where(
              (e) => e['type'] == 'playback_completed',
            ),
            hasLength(1),
          );
          await h.telemetry.flush();
          expect(
            h.events.where((e) => e['action'] == 'playback.control.ack'),
            isEmpty,
          );
        },
      );
    }
  }

  testWidgets(
    'accepted completion cancels an older receipt even before its stream arrives',
    (tester) async {
      final h = RecoveryHarness(recoverySession());
      addTearDown(h.dispose);
      await tester.pump();
      expect(await h.commands.pause(55000), isTrue);
      await tester.pump();
      h.db.publishTransactions = false;
      expect(await h.commands.complete(), isTrue);
      await tester.pump(const Duration(seconds: 15));
      expect(h.operationEvents, isEmpty);
      await h.telemetry.flush();
      expect(
        h.events.where(
          (e) =>
              e['action'] == 'playback.control.ack' &&
              e['outcome'] == 'cancelled',
        ),
        hasLength(1),
      );
      h.db.deliver(h.db.server);
      await tester.pump();
      await tester.pump(const Duration(seconds: 15));
      expect(h.operationEvents, isEmpty);
      expect(
        h.db.operationEvents.values.where(
          (e) => e['type'] == 'playback_completed',
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'failed completion preserves the failure and an older genuine receipt timeout',
    (tester) async {
      final h = RecoveryHarness(recoverySession());
      addTearDown(h.dispose);
      await tester.pump();
      expect(await h.commands.pause(55000), isTrue);
      await tester.pump();
      h.db.beforeTransaction = () async =>
          throw StateError('server unreachable');
      expect(await h.commands.complete(), isFalse);
      await tester.pump(const Duration(seconds: 15));
      expect(
        h.container.read(playbackActionControllerProvider).hasError,
        isTrue,
      );
      expect(
        h.operationEvents.where((e) => e.event.type == 'command_failed'),
        hasLength(1),
      );
      expect(
        h.operationEvents.where(
          (e) => e.event.type == 'command_receipt_failed',
        ),
        hasLength(3),
      );
      expect(
        h.db.operationEvents.values.where(
          (e) => e['type'] == 'playback_completed',
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'another controller completing the same class cancels the pending receipt',
    (tester) async {
      final h = RecoveryHarness(recoverySession());
      addTearDown(h.dispose);
      await tester.pump();
      expect(await h.commands.pause(55000), isTrue);
      await tester.pump();
      h.db.deliver(recoverySession(revision: 3, status: 'completed'));
      await tester.pump(const Duration(seconds: 15));
      expect(h.operationEvents, isEmpty);
    },
  );
}
