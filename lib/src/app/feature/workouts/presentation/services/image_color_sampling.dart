import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Inverts zoom/pan, then rejects contain letterboxing instead of clamping it.
Offset? imagePixelAt({
  required Offset position,
  required Size viewport,
  required Size image,
  required Matrix4 transform,
}) {
  if (viewport.isEmpty ||
      image.isEmpty ||
      !(Offset.zero & viewport).contains(position))
    return null;
  final inverse = Matrix4.tryInvert(transform);
  if (inverse == null) return null;
  final scene = MatrixUtils.transformPoint(inverse, position);
  final bounds = containedImageRect(image, viewport);
  if (!bounds.contains(scene)) return null;
  return Offset(
    ((scene.dx - bounds.left) * image.width / bounds.width).floorToDouble(),
    ((scene.dy - bounds.top) * image.height / bounds.height).floorToDouble(),
  );
}

Rect containedImageRect(Size image, Size viewport) => Alignment.center.inscribe(
  applyBoxFit(BoxFit.contain, image, viewport).destination,
  Offset.zero & viewport,
);

/// Owns one original-resolution image handle and straight (not premultiplied)
/// RGBA bytes for this dialog only. No screenshots, overlays, or extra cache.
class ImageColorPixels {
  ImageColorPixels(this.image, this.rgba);
  final ui.Image image;
  final ByteData rgba;
  Size get size => Size(image.width.toDouble(), image.height.toDouble());
  Color? colorAt(Offset pixel) {
    final x = pixel.dx.floor(), y = pixel.dy.floor();
    if (x < 0 || y < 0 || x >= image.width || y >= image.height) return null;
    final offset = (y * image.width + x) * 4;
    if (rgba.getUint8(offset + 3) == 0) return null;
    // Existing timer fields are RGB. Preserve the source RGB even for partial
    // alpha, never sample a color composited with the preview background.
    return Color.fromARGB(
      255,
      rgba.getUint8(offset),
      rgba.getUint8(offset + 1),
      rgba.getUint8(offset + 2),
    );
  }

  void dispose() => image.dispose();
}

/// Removes the listener on success, failure, timeout, and cancellation. Any
/// decode completing after cancellation releases its private image handle.
class ImageColorRead {
  ImageColorRead(ImageProvider provider, ImageConfiguration configuration) {
    _listener = ImageStreamListener(
      _receive,
      onError: (Object error, StackTrace? stack) => _fail(error),
    );
    _timer = Timer(
      const Duration(seconds: 20),
      () => _fail(TimeoutException('image pixels')),
    );
    try {
      _stream = provider.resolve(configuration);
      _stream!.addListener(_listener);
    } catch (error) {
      _fail(error);
    }
  }
  final _ready = Completer<ImageColorPixels>();
  Future<ImageColorPixels> get future => _ready.future;
  ImageStream? _stream;
  late final ImageStreamListener _listener;
  Timer? _timer;
  bool _received = false;
  bool _finished = false;

  void _release() {
    _stream?.removeListener(_listener);
    _timer?.cancel();
  }

  void _fail(Object error) {
    if (_finished) return;
    _finished = true;
    _release();
    _ready.completeError(error);
  }

  void cancel() => _fail(StateError('Image sampling cancelled'));

  Future<void> _receive(ImageInfo info, bool synchronous) async {
    if (_received || _finished) {
      info.dispose();
      return;
    }
    _received = true;
    _stream?.removeListener(_listener);
    ui.Image? owned;
    try {
      owned = info.image.clone();
    } catch (error) {
      _fail(error);
      return;
    } finally {
      info.dispose();
    }
    try {
      // Bound the additional RGBA allocation without resampling source pixels.
      if (owned.width * owned.height > 16 * 1024 * 1024) {
        throw const FormatException('Image too large for pixel sampling');
      }
      final bytes = await owned.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (_finished) return;
      if (bytes == null ||
          bytes.lengthInBytes != owned.width * owned.height * 4) {
        throw const FormatException('Image pixels unavailable');
      }
      _finished = true;
      _release();
      _ready.complete(ImageColorPixels(owned, bytes));
      owned = null; // Ownership transfers to the dialog.
    } catch (error) {
      _fail(error);
    } finally {
      owned?.dispose();
    }
  }
}
