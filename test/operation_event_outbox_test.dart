import 'dart:convert';

import 'package:cloud_board/src/app/core/diagnostics/diagnostic_queue.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';
import 'package:cloud_board/src/app/feature/operations/data/operation_event_writer.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:flutter_test/flutter_test.dart';

OperationEvent _event(String id, int now) => OperationEvent(
  id: id,
  eventId: id,
  type: 'display_playback_completed',
  phase: 'local_completion',
  connected: false,
  occurredAtMs: now,
  deviceId: 'display',
  workoutId: 'workout',
  workoutName: 'Class',
  sessionId: 'session',
  scheduled: false,
  scheduledAtMs: null,
);

void main() {
  testWidgets(
    'offline operations survive queue recreation with their exact ID and occurrence',
    (tester) async {
      String? stored;
      final now = DateTime(2026, 10, 20);
      final delivered = <OperationEvent>[];
      var online = false;
      DiagnosticQueue makeQueue() => DiagnosticQueue(
        clock: () => now,
        read: () async => stored,
        write: (value) async => stored = value,
        send: (value, account) async {
          if (!online) throw StateError('offline');
          delivered.add(
            OperationEventModel.fromJson(
              Map<String, dynamic>.from(value['operation'] as Map),
            ).toEntity(),
          );
        },
      );
      var queue = makeQueue();
      await queue.setAccount('owner/display/binding');
      var writer = OperationEventWriter((_) async {}, retryQueue: queue);
      final original = _event('same-id', now.millisecondsSinceEpoch);
      await writer.record(original);
      await tester.pump();
      expect(delivered, isEmpty);
      expect(jsonDecode(stored!)['events'], hasLength(1));
      queue.dispose();
      writer.dispose();
      queue = makeQueue();
      writer = OperationEventWriter((_) async {}, retryQueue: queue);
      await queue.setAccount('owner/display/binding');
      await writer.record(original);
      online = true;
      await queue.flush();
      expect(delivered, [original]);
      expect(jsonDecode(stored!)['events'], isEmpty);
      writer.dispose();
      queue.dispose();
    },
  );

  testWidgets(
    'account replacement drops previous device events; queue is bounded',
    (tester) async {
      String? stored;
      final now = DateTime(2026, 10, 20);
      final delivered = <String>[];
      final queue = DiagnosticQueue(
        capacity: 2,
        clock: () => now,
        read: () async => stored,
        write: (value) async => stored = value,
        send: (value, account) async =>
            delivered.add(value['eventId'] as String),
      );
      final writer = OperationEventWriter((_) async {}, retryQueue: queue);
      addTearDown(() {
        writer.dispose();
        queue.dispose();
      });
      await queue.setAccount('owner-a/display-a');
      for (var i = 0; i < 3; i++) {
        await writer.record(_event('a-$i', now.millisecondsSinceEpoch));
      }
      expect(jsonDecode(stored!)['events'], hasLength(2));
      await queue.setAccount('owner-b/display-b');
      await writer.record(_event('b', now.millisecondsSinceEpoch));
      await queue.flush();
      expect(delivered, ['b']);
      writer.dispose();
      queue.dispose();
    },
  );
}
