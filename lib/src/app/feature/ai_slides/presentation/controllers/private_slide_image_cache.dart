import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Owned by one authorized catalog lifetime, never Flutter's global image cache.
/// Eight 640×360 RGBA thumbnails retain at most 7.1 MiB of decoded pixels.
class PrivateSlideImageCache {
  PrivateSlideImageCache({this.lifetime = const Duration(minutes: 2)});
  final Duration lifetime;
  final _images = <String, ui.Image>{};
  final _pending = <String, Future<void>>{};
  final _expires = <String, Timer>{};
  bool _disposed = false;
  Set<String> _allowed = {};

  void retainKeys(Set<String> allowed) {
    _allowed = allowed;
    for (final key
        in _images.keys.where((key) => !allowed.contains(key)).toList()) {
      _evict(key);
    }
    _pending.removeWhere((key, _) => !allowed.contains(key));
  }

  ui.Image? peek(String key) {
    if (_disposed || !_allowed.contains(key)) return null;
    final image = _images.remove(key);
    if (image != null) _images[key] = image;
    return image?.clone();
  }

  Future<ui.Image?> load(String key, Future<Uint8List?> Function() read) async {
    final cached = peek(key);
    if (cached != null) return cached;
    final pending = _pending[key] ??= _decode(key, read);
    try {
      await pending;
      // Clone only a still-owned entry: another completed request or revocation
      // may have evicted the decoded handle before this continuation resumes.
      return peek(key);
    } finally {
      if (identical(_pending[key], pending)) _pending.remove(key);
    }
  }

  Future<void> _decode(String key, Future<Uint8List?> Function() read) async {
    final bytes = await read();
    if (_disposed || !_allowed.contains(key) || bytes == null) return;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 640,
      allowUpscaling: false,
    );
    try {
      if (codec.frameCount != 1) {
        throw const FormatException('움직이는 미리보기는 지원하지 않아요.');
      }
      final image = (await codec.getNextFrame()).image;
      if (_disposed || !_allowed.contains(key)) {
        image.dispose();
        return;
      }
      while (_images.length >= 8) {
        _evict(_images.keys.first);
      }
      _images[key] = image;
      _expires[key] = Timer(lifetime, () => _evict(key));
    } finally {
      codec.dispose();
    }
  }

  void _evict(String key) {
    _expires.remove(key)?.cancel();
    _images.remove(key)?.dispose();
  }

  void dispose() {
    _disposed = true;
    for (final key in _images.keys.toList()) {
      _evict(key);
    }
    _pending.clear();
  }
}
