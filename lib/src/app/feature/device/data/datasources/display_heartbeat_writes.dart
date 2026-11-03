/// Retains the original SDK Future even when a caller stops waiting for it.
/// Equal intents join one write; a ready ACK or a new connection waits its turn
/// and must perform its own write before it can report success.
class DisplayHeartbeatWrites {
  final _pending = <Object, Future<void>>{};
  Future<void>? _tail;

  bool get isIdle => _pending.isEmpty;

  Future<void> run(Object intent, Future<void> Function() write) {
    final existing = _pending[intent];
    if (existing != null) return existing;
    final previous = _tail;
    late final Future<void> work;
    work =
        Future<void>(() async {
          if (previous != null) {
            try {
              await previous;
            } catch (_) {
              // A failed old connection cannot poison the new connection's write.
            }
          }
          await write();
        }).whenComplete(() {
          _pending.remove(intent);
          if (identical(_tail, work)) _tail = null;
        });
    _pending[intent] = work;
    _tail = work;
    return work;
  }
}
