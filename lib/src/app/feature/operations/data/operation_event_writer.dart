import 'dart:async';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

/// Best-effort telemetry: retry the same ID and occurrence timestamp. It never
/// retries a playback command and callers never need to await this queue.
class OperationEventWriter {
  OperationEventWriter(
    this.write, {
    this.retryDelay = const Duration(seconds: 2),
    this.timeout = const Duration(seconds: 5),
  });
  final Future<void> Function(OperationEvent) write;
  final Duration retryDelay, timeout;
  final _inFlight = <String, Future<void>>{};
  bool _disposed = false;

  Future<void> record(OperationEvent event) {
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
