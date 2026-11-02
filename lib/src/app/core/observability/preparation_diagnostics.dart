import 'dart:async';

import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';

/// Passive observations plus one bounded, read-only probe after a timeout.
/// Never retries/cancels writes, changes readiness, or reconnects the SDK.
class PreparationDiagnostics {
  PreparationDiagnostics({this.probe, int Function()? elapsedMs})
    : _elapsedMs =
          elapsedMs ?? (Stopwatch()..start()).elapsedMillisecondsGetter;

  final Future<Map<String, Object>> Function(String requestId)? probe;
  final int Function() _elapsedMs;
  String _connection = 'unknown', _lifecycle = 'unknown';
  int? _connectionAt, _lifecycleAt, _lastProbeAt;
  int _changes = 0, _pendingWrites = 0;
  bool _disposed = false, _probing = false;

  void connectionChanged(bool? connected, {bool error = false}) {
    final next = error
        ? 'error'
        : connected == null
        ? 'unknown'
        : connected
        ? 'connected'
        : 'disconnected';
    if (next == _connection) return;
    if (_connectionAt != null) _changes++;
    _connection = next;
    _connectionAt = _elapsedMs();
  }

  void lifecycleChanged(String state) {
    if (_lifecycle == state) return;
    _lifecycle = state;
    _lifecycleAt = _elapsedMs();
  }

  Map<String, Object> snapshot() => {
    'connection': _connection,
    'connectionChanges': _changes.clamp(0, 1000000),
    'observerAgeMs': _elapsedMs().clamp(0, 2592000000),
    if (_connectionAt != null)
      'connectionAgeMs': (_elapsedMs() - _connectionAt!).clamp(0, 2592000000),
    'lifecycle': _lifecycle,
    if (_lifecycleAt != null)
      'lifecycleAgeMs': (_elapsedMs() - _lifecycleAt!).clamp(0, 2592000000),
    'pendingWrites': _pendingWrites.clamp(0, 1000),
  };

  Future<void> observeRequest({
    required Future<void> Function() write,
    required OperationAttempt attempt,
    required String requestId,
    required bool Function() superseded,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final started = _elapsedMs();
    var timedOut = false;
    _pendingWrites++;
    void settled(Object? error) {
      _pendingWrites--;
      if (!timedOut || _disposed) return;
      final late = attempt.followUp(
        'tv.prepare.settlement',
        trace: {
          ...snapshot(),
          'requestId': requestId,
          'writeElapsedMs': (_elapsedMs() - started).clamp(0, 86400000),
          'superseded': superseded(),
        },
      );
      if (error == null) {
        late?.success();
      } else {
        late?.failure(error);
      }
    }

    // The original Future remains observed after timeout; SDK writes are not
    // cancelled by Future.timeout and can still settle after the dialog closes.
    final observed = Future<void>.sync(write).then<void>(
      (_) => settled(null),
      onError: (Object error, StackTrace stack) {
        settled(error);
        Error.throwWithStackTrace(error, stack);
      },
    );
    await observed.timeout(
      timeout,
      onTimeout: () {
        timedOut = true;
        // No probe/telemetry Future is awaited by the product action.
        unawaited(_probe(attempt, requestId));
        throw TimeoutException(
          'Preparation request acknowledgement timed out',
          timeout,
        );
      },
    );
  }

  Future<void> _probe(OperationAttempt parent, String requestId) async {
    if (_disposed ||
        probe == null ||
        _probing ||
        (_lastProbeAt != null && _elapsedMs() - _lastProbeAt! < 60000)) {
      return;
    }
    _lastProbeAt = _elapsedMs();
    final attempt = parent.followUp(
      'tv.prepare.probe',
      trace: {...snapshot(), 'requestId': requestId},
    );
    if (attempt == null) return;
    _probing = true;
    try {
      final result = await probe!(requestId)
          .timeout(const Duration(seconds: 6));
      if (!_disposed) attempt.success(trace: {...snapshot(), ...result});
    } on PreparationProbeFailure catch (error) {
      if (!_disposed) {
        attempt.failure(error.code, trace: {...snapshot(), ...error.trace});
      }
    } catch (error) {
      if (!_disposed) attempt.failure(error, trace: snapshot());
    } finally {
      _probing = false;
    }
  }

  void dispose() => _disposed = true;
}

class PreparationProbeFailure implements Exception {
  const PreparationProbeFailure(this.code, this.trace);
  final String code;
  final Map<String, Object> trace;
}

extension on Stopwatch {
  int elapsedMillisecondsGetter() => elapsedMilliseconds;
}
