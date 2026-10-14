import 'dart:async';

/// Orders a connection's disconnect registration, server authentication, and
/// presence publication. Every async boundary is fenced by the connection epoch.
class DisplayPresenceCoordinator {
  DisplayPresenceCoordinator({
    required this.newConnectionId,
    required this.registerDisconnect,
    required this.verify,
    required this.publish,
    this.onError,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
    ],
  });
  final String Function() newConnectionId;
  final Future<void> Function(String connectionId) registerDisconnect;
  final Future<void> Function(String connectionId) verify;
  final Future<void> Function(String connectionId, bool Function() isCurrent)
  publish;
  final void Function(Object error, StackTrace stack)? onError;
  final List<Duration> retryDelays;
  StreamSubscription<bool>? _subscription;
  Timer? _retry;
  bool _connected = false, _disposed = false, _running = false;
  int _epoch = 0, _attempt = 0;
  bool _exhausted = false;
  bool get exhausted => _exhausted;
  final _firstReady = Completer<void>();
  Future<void> get firstReady => _firstReady.future;

  void start(Stream<bool> connection) {
    _subscription = connection.distinct().listen(
      (connected) {
        _connected = connected;
        _epoch++;
        _attempt = 0;
        _exhausted = false;
        _retry?.cancel();
        if (connected) unawaited(_drain());
      },
      onError: (Object error, StackTrace stack) => onError?.call(error, stack),
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
      if (!_firstReady.isCompleted) _firstReady.complete();
    } catch (error, stack) {
      if (current()) {
        onError?.call(error, stack);
        if (_attempt < retryDelays.length) {
          _retry = Timer(retryDelays[_attempt++], () => unawaited(_drain()));
        } else {
          _exhausted = true;
          if (!_firstReady.isCompleted) _firstReady.completeError(error, stack);
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
    unawaited(_subscription?.cancel());
  }
}
