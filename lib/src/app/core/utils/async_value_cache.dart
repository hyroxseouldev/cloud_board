/// Bounded, expiring values with one in-flight request per key. Invalidating a
/// key also prevents an older request from replacing a newer saved value.
class AsyncValueCache<K, V> {
  AsyncValueCache({
    this.capacity = 24,
    this.ttl = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : assert(capacity > 0),
       _clock = clock ?? DateTime.now;

  final int capacity;
  final Duration ttl;
  final DateTime Function() _clock;
  final _values = <K, ({V value, DateTime expires})>{};
  final _pending = <K, Future<V>>{};

  Iterable<K> get keys => {..._values.keys, ..._pending.keys};

  Future<V> load(K key, Future<V> Function() fetch) {
    final cached = _values.remove(key);
    if (cached != null && _clock().isBefore(cached.expires)) {
      _values[key] = cached;
      return Future.value(cached.value);
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    late final Future<V> request;
    request = Future<V>.sync(fetch)
        .then((value) {
          if (identical(_pending[key], request)) put(key, value);
          return value;
        })
        .whenComplete(() {
          if (identical(_pending[key], request)) _pending.remove(key);
        });
    _pending[key] = request;
    return request;
  }

  void put(K key, V value) {
    invalidate(key);
    _values[key] = (value: value, expires: _clock().add(ttl));
    while (_values.length > capacity) {
      _values.remove(_values.keys.first);
    }
  }

  void invalidate(K key) {
    _values.remove(key);
    _pending.remove(key);
  }

  void clear() {
    _values.clear();
    _pending.clear();
  }
}
