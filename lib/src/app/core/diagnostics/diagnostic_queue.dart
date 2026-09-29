import 'dart:async';
import 'dart:convert';
import 'dart:math';

/// Bounded, account-scoped web retry queue; stored JSON contains sanitized data only.
class DiagnosticQueue {
  DiagnosticQueue({
    required this.read,
    required this.write,
    required this.send,
    DateTime Function()? clock,
    this.capacity = 30,
    this.ttl = const Duration(hours: 24),
  }) : clock = clock ?? DateTime.now;
  final Future<String?> Function() read;
  final Future<void> Function(String?) write;
  final Future<void> Function(Map<String, dynamic>, String account) send;
  final DateTime Function() clock;
  final int capacity;
  final Duration ttl;
  Future<void> _pending = Future.value();
  String? _account;
  int _generation = 0;
  int _failures = 0;
  Timer? _retry;
  bool _disposed = false;
  Future<void> _serialize(Future<void> Function() task) {
    final next = _pending.then((_) => task());
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> setAccount(String? account) {
    if (_account == account) return _pending;
    _account = account;
    final generation = ++_generation;
    _retry?.cancel();
    return _serialize(() async {
      if (generation != _generation || _disposed) return;
      final stored = await _load();
      if (stored['account'] != account || account == null) await write(null);
      _failures = 0;
      if (account != null) _schedule(Duration.zero);
    });
  }

  Future<Map<String, dynamic>> _load() async {
    try {
      return jsonDecode(await read() ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> stored) {
    if (stored['account'] != _account || stored['events'] is! List) return [];
    final result = <Map<String, dynamic>>[];
    for (final item in stored['events'] as List) {
      if (item is! Map<String, dynamic>) continue;
      final time = DateTime.tryParse(item['occurredAt']?.toString() ?? '');
      if (time != null &&
          clock().difference(time) <= ttl &&
          !time.isAfter(clock().add(const Duration(minutes: 5)))) {
        result.add(item);
      }
    }
    return result;
  }

  Future<void> enqueue(Map<String, dynamic> event) {
    final account = _account, generation = _generation;
    return _serialize(() async {
      if (_disposed || account == null || generation != _generation) return;
      final events = _items(await _load());
      if (!events.any((e) => e['eventId'] == event['eventId'])) {
        events.add(event);
      }
      if (events.length > capacity) {
        events.removeRange(0, events.length - capacity);
      }
      if (generation != _generation) return;
      await write(jsonEncode({'account': account, 'events': events}));
      _schedule(Duration.zero);
    });
  }

  void _schedule(Duration delay) {
    if (_disposed || _account == null || _retry?.isActive == true) return;
    _retry = Timer(delay, () => unawaited(flush().catchError((Object _) {})));
  }

  Future<void> flush() {
    final generation = _generation, account = _account;
    return _serialize(() async {
      if (_disposed || account == null || generation != _generation) return;
      final events = _items(await _load());
      if (generation != _generation || _disposed) return;
      await write(jsonEncode({'account': account, 'events': events}));
      while (events.isNotEmpty && generation == _generation && !_disposed) {
        try {
          await send(events.first, account).timeout(const Duration(seconds: 8));
        } catch (_) {
          _failures++;
          _retry = null;
          _schedule(Duration(seconds: min(300, 1 << min(_failures, 8))));
          break;
        }
        if (generation != _generation || _disposed) return;
        events.removeAt(0);
        _failures = 0;
        await write(jsonEncode({'account': account, 'events': events}));
      }
    });
  }

  void dispose() {
    _disposed = true;
    ++_generation;
    _retry?.cancel();
  }
}
