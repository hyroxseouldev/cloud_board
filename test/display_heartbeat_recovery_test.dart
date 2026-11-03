import 'dart:async';

import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/display_heartbeat_writes.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/heartbeat_recovery_budget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'timed-out callers join the original SDK write until it settles',
    () async {
      final writes = DisplayHeartbeatWrites();
      final gate = Completer<void>();
      var started = 0;
      Future<void> send() => writes.run('connection/regular', () {
        started++;
        return gate.future;
      });
      final original = send();
      for (var retry = 0; retry < 4; retry++) {
        expect(identical(send(), original), isTrue);
        await expectLater(
          send().timeout(const Duration(milliseconds: 1)),
          throwsA(isA<TimeoutException>()),
        );
      }
      expect(started, 1);
      expect(writes.isIdle, isFalse);
      gate.complete();
      await original;
      expect(writes.isIdle, isTrue);
      await send();
      expect(started, 2);
    },
  );

  test(
    'ready and a new connection require their own serialized write',
    () async {
      final writes = DisplayHeartbeatWrites();
      final gate = Completer<void>();
      final log = <String>[];
      final regular = writes.run('old/regular', () async {
        log.add('regular');
        await gate.future;
      });
      final ready = writes.run('old/ready', () async {
        log.add('ready');
      });
      final next = writes.run('new/regular', () async {
        log.add('new');
      });
      expect(
        identical(
          ready,
          writes.run('old/ready', () async {
            fail('must coalesce');
          }),
        ),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(log, ['regular']);
      gate.completeError(StateError('old transport failed'));
      await expectLater(regular, throwsStateError);
      await Future.wait([ready, next]);
      expect(log, ['regular', 'ready', 'new']);
      expect(writes.isIdle, isTrue);
    },
  );

  test(
    'failure normalization remains compatible and retains raw diagnostic codes',
    () {
      for (final entry in {
        'overridden-by-set': 'aborted',
        'max-retries': 'aborted',
        'data-stale': 'aborted',
        'disconnected': 'unavailable',
        'network-error': 'unavailable',
        'expired-token': 'unauthenticated',
        'invalid-token': 'unauthenticated',
        'write-cancelled': 'cancelled',
      }.entries) {
        final error = FirebaseException(
          plugin: 'firebase_database',
          code: entry.key,
        );
        expect(operationFailureCode(error), entry.value);
        expect(diagnosticCode(error), 'firebase_database/${entry.key}');
      }
    },
  );

  test('recovery needs two cycles, standby, cooldown and a bounded budget', () {
    var now = DateTime(2026);
    final budget = HeartbeatRecoveryBudget(clock: () => now);
    bool failCycle({bool standby = true, bool denied = false}) =>
        budget.failed(standby: standby, permissionStopped: denied);
    expect(failCycle(), isFalse);
    expect(failCycle(standby: false), isFalse);
    expect(failCycle(denied: true), isFalse);
    expect(failCycle(), isTrue);
    expect(failCycle(), isFalse);
    for (var i = 0; i < 2; i++) {
      now = now.add(const Duration(minutes: 2));
      expect(failCycle(), isTrue);
    }
    now = now.add(const Duration(minutes: 30));
    expect(failCycle(), isFalse);
    budget.succeeded();
    expect(failCycle(), isFalse);
    expect(failCycle(), isTrue);
  });
}
