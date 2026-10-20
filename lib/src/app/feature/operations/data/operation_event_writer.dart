import 'dart:async';

import 'package:cloud_board/src/app/core/diagnostics/diagnostic_queue.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

/// Best-effort telemetry: retry the same ID and occurrence timestamp. It never
/// retries a playback command and callers never need to await this queue.
class OperationEventWriter {
  OperationEventWriter(
    this.write, {
    this.retryDelay = const Duration(seconds: 2),
    this.timeout = const Duration(seconds: 5),
    this.retryQueue,
  });
  final Future<void> Function(OperationEvent) write;
  final Duration retryDelay, timeout;
  final DiagnosticQueue? retryQueue;
  final _inFlight = <String, Future<void>>{};
  bool _disposed = false;

  Future<void> record(OperationEvent event) {
    if (_disposed) return Future.value();
    if (retryQueue != null) {
      return retryQueue!.enqueue({
        'eventId': event.eventId ?? event.id,
        'occurredAt': DateTime.fromMillisecondsSinceEpoch(event.occurredAtMs)
            .toUtc()
            .toIso8601String(),
        'operation': OperationEventModel.fromEntity(event).toJson(),
      });
    }
    final id = event.eventId ?? event.id;
    return _inFlight[id] ??= _send(event).whenComplete(() {
      _inFlight.remove(id);
    });
  }

  Future<void> _send(OperationEvent event) async {
    for (var attempt = 0; attempt < 3 && !_disposed; attempt++) {
      try {
        await write(event).timeout(timeout);
        return;
      } catch (_) {
        if (attempt < 2 && !_disposed) await Future<void>.delayed(retryDelay);
      }
    }
    // Permanent failure is a missing record, not a successful class count.
  }

  void dispose() => _disposed = true;
}
