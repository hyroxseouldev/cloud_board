import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

final _retainedClasses = <WorkoutImageRetention>{};

/// Compressed bytes are kept independently of Flutter's evictable decoded
/// image cache. URLs remain private to the owning display scope's lifetime.
Uint8List? retainedWorkoutImage(String source) {
  for (final cache in _retainedClasses) {
    final bytes = cache.bytesFor(source);
    if (bytes != null) return bytes;
  }
  return null;
}

class WorkoutImageRetention {
  WorkoutImageRetention({
    this.maximumBytes = 64 * 1024 * 1024,
    this.maximumImageBytes = 16 * 1024 * 1024,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new {
    _retainedClasses.add(this);
  }

  // Four times the existing embedded-image cache, for at most one class.
  // HTML-only fallback images are charged their decoded RGBA size.
  final int maximumBytes, maximumImageBytes;
  final http.Client Function() _clientFactory;
  final _bytes = <String, Uint8List>{};
  final _fallbacks = <String, void Function()>{};
  final _clients = <http.Client>{};
  final _pending = <String, Future<void>>{};
  int _used = 0, _generation = 0;
  String? _sessionId;
  Set<String> _sources = {};
  Timer? _expiry;
  bool _disposed = false;

  String? get sessionId => _sessionId;
  int get retainedBytes => _used;
  Uint8List? bytesFor(String source) => _bytes[source];

  void prepare(
    String sessionId,
    Duration expiresIn, {
    Iterable<String> sources = const [],
  }) {
    if (_disposed) return;
    if (_sessionId != sessionId) {
      clear();
      _sessionId = sessionId;
    }
    _sources = sources.toSet();
    _expiry?.cancel();
    _expiry = Timer(expiresIn.isNegative ? Duration.zero : expiresIn, clear);
  }

  void activate(String sessionId, {Iterable<String> sources = const []}) {
    if (_disposed) return;
    final next = sources.toSet();
    // Preparation and playback deliberately use different IDs. Transfer only
    // the exact prepared image manifest, within the same authorization scope.
    final sameManifest =
        _sources.length == next.length && _sources.containsAll(next);
    if (!sameManifest) clear();
    _sessionId = sessionId;
    _sources = next;
    _expiry?.cancel();
    _expiry = null;
  }

  Future<void> load(String source) {
    if (_disposed ||
        _sessionId == null ||
        _bytes.containsKey(source) ||
        _fallbacks.containsKey(source) ||
        !(source.startsWith('https://') || source.startsWith('http://'))) {
      return Future.value();
    }
    final previous = _pending[source];
    if (previous != null) return previous;
    late Future<void> task;
    task = _download(source).whenComplete(() {
      if (identical(_pending[source], task)) _pending.remove(source);
    });
    return _pending[source] = task;
  }

  Future<void> _download(String source) async {
    final generation = _generation;
    final client = _clientFactory();
    _clients.add(client);
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(source)))
          .timeout(const Duration(seconds: 10));
      final available = maximumBytes - _used;
      final limit = available < maximumImageBytes
          ? available
          : maximumImageBytes;
      if (response.statusCode != 200 ||
          limit <= 0 ||
          (response.contentLength ?? 0) > limit) {
        throw StateError('Image exceeds the active class cache limit');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 10),
      )) {
        if (_disposed || generation != _generation) return;
        if (builder.length + chunk.length > limit) {
          throw StateError('Image exceeds the active class cache limit');
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (_disposed || generation != _generation) return;
      // Concurrent downloads share one bounded budget.
      if (bytes.isEmpty || _used + bytes.length > maximumBytes) {
        throw StateError('Image exceeds the active class cache limit');
      }
      _bytes[source] = bytes;
      _used += bytes.length;
    } finally {
      _clients.remove(client);
      client.close();
    }
  }

  /// Keeps the existing HTML provider alive when CORS prevents byte access.
  /// Returns false when the single-class memory budget cannot accommodate it.
  bool retainFallback(
    String source,
    int decodedBytes,
    void Function() release,
  ) {
    if (_disposed ||
        _sessionId == null ||
        _fallbacks.containsKey(source) ||
        _bytes.containsKey(source) ||
        decodedBytes <= 0 ||
        _used + decodedBytes > maximumBytes) {
      return false;
    }
    _fallbacks[source] = release;
    _used += decodedBytes;
    return true;
  }

  void clear() {
    _generation++;
    _expiry?.cancel();
    _expiry = null;
    _sessionId = null;
    _sources = {};
    for (final client in _clients.toList()) {
      client.close();
    }
    _clients.clear();
    for (final release in _fallbacks.values) {
      release();
    }
    _fallbacks.clear();
    _pending.clear();
    _bytes.clear();
    _used = 0;
  }

  void dispose() {
    _disposed = true;
    clear();
    _retainedClasses.remove(this);
  }
}
