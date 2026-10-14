import 'dart:async';

import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_connection_state.dart';

/// Orders a connection's disconnect registration, server authentication, and
/// presence publication. Every async boundary is fenced by the connection epoch.
class DisplayPresenceCoordinator {
  DisplayPresenceCoordinator({
    required this.newConnectionId,
    required this.registerDisconnect,
    required this.verify,
    required this.publish,
    this.onError,
    this.onState,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
    ],
  }) {
    _ready.future.ignore();
  }
  final String Function() newConnectionId;
  final Future<void> Function(String connectionId) registerDisconnect;
  final Future<void> Function(String connectionId) verify;
  final Future<void> Function(String connectionId, bool Function() isCurrent)
  publish;
  final void Function(Object error, StackTrace stack)? onError;
  final void Function(DisplayConnectionState state)? onState;
  final List<Duration> retryDelays;
  StreamSubscription<bool>? _subscription;
  Timer? _retry;
  bool _connected = false, _disposed = false, _running = false;
  int _epoch = 0, _attempt = 0;
  bool _exhausted = false;
  bool get exhausted => _exhausted;
  var _ready = Completer<void>();
  Future<void> get currentReady => _ready.future;
  // Kept for existing callers; each new connection now has fresh readiness.
  Future<void> get firstReady => currentReady;

  void _resetReadiness() {
    if (_ready.isCompleted) {
      _ready = Completer<void>();
      _ready.future.ignore();
    }
    onState?.call(
      DisplayConnectionState(
        phase: DisplayConnectionPhase.verifying,
        generation: _epoch,
      ),
    );
  }

  void _fail(Object error, StackTrace stack) {
    _exhausted = true;
    onState?.call(
      DisplayConnectionState(
        phase: DisplayConnectionPhase.failed,
        generation: _epoch,
        error: error,
        stack: stack,
      ),
    );
    if (!_ready.isCompleted) _ready.completeError(error, stack);
  }

  void start(Stream<bool> connection) {
    _subscription = connection.distinct().listen(
      (connected) {
        _connected = connected;
        _epoch++;
        _attempt = 0;
        _exhausted = false;
        _retry?.cancel();
        _resetReadiness();
        if (connected) unawaited(_drain());
      },
      onError: (Object error, StackTrace stack) {
        if (_disposed) return;
        _connected = false;
        _epoch++;
        _retry?.cancel();
        _resetReadiness();
        onError?.call(error, stack);
        _fail(error, stack);
      },
    );
  }

  Future<void> _drain() async {
    if (_running || _disposed || !_connected) return;
    _running = true;
    final epoch = _epoch;
    bool current() => !_disposed && _connected && epoch == _epoch;
    try {
      final connectionId = newConnectionId();
      await registerDisconnect(connectionId);
      if (!current()) return;
      await verify(connectionId);
      if (!current()) return;
      await publish(connectionId, current);
      if (!current()) return;
      _attempt = 0;
      _exhausted = false;
      onState?.call(
        DisplayConnectionState(
          phase: DisplayConnectionPhase.ready,
          generation: epoch,
        ),
      );
      if (!_ready.isCompleted) _ready.complete();
    } catch (error, stack) {
      if (current()) {
        onError?.call(error, stack);
        final code = operationFailureCode(error);
        if (code != 'permission-denied' &&
            code != 'unauthenticated' &&
            _attempt < retryDelays.length) {
          _retry = Timer(retryDelays[_attempt++], () => unawaited(_drain()));
        } else {
          _fail(error, stack);
        }
      }
    } finally {
      _running = false;
      // An old server verification may still be resolving during reconnect.
      // Serialize the next verification so it always becomes the latest proof.
      if (!_disposed && _connected && epoch != _epoch) unawaited(_drain());
    }
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _retry?.cancel();
    if (!_ready.isCompleted) {
      _ready.completeError(StateError('디스플레이 연결이 변경되었습니다.'));
    }
    unawaited(_subscription?.cancel());
  }
}
