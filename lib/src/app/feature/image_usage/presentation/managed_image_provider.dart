import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';

Future<Uint8List> authenticatedManagedImageBytes(String source) async {
  final auth = FirebaseAuth.instance;
  final client = ImageUsageDataSource.forApp(auth.app, auth: auth);
  try {
    return await client.media(source);
  } finally {
    client.dispose();
  }
}

/// The only managed-image provider on web and native. HTTP gets an ID token and
/// a participant-bound lease before any body is requested, then MemoryImage
/// owns decoding. It never delegates to NetworkImage or an HTML image element.
class ManagedImageProvider extends ImageProvider<ManagedImageProvider> {
  ManagedImageProvider(
    this.source, {
    Future<Uint8List> Function(String)? load,
    Object? scope,
  }) : load = load ?? authenticatedManagedImageBytes,
       scope =
           scope ??
           (load == null && Firebase.apps.isNotEmpty
               ? FirebaseAuth.instance.currentUser
               : null);
  final String source;
  // Preserve the existing Flutter provider's stable identity across a clock/UI
  // rebuild, while a different auth session cannot reuse private decoded bytes.
  final Object? scope;
  @override
  bool operator ==(Object other) =>
      other is ManagedImageProvider &&
      other.source == source &&
      other.scope == scope &&
      other.load == load;
  @override
  int get hashCode => Object.hash(source, scope, load);
  final Future<Uint8List> Function(String) load;
  @override
  Future<ManagedImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    ManagedImageProvider key,
    ImageDecoderCallback decode,
  ) => _ManagedMemoryCompleter(load(source), decode);
}

class _ManagedMemoryCompleter extends ImageStreamCompleter {
  _ManagedMemoryCompleter(
    Future<Uint8List> bytes,
    ImageDecoderCallback decode,
  ) {
    // Keep the proxy alive while authenticated I/O is pending. The MemoryImage
    // stream and its listener are released when the final consumer leaves.
    final pending = keepAlive();
    unawaited(() async {
      try {
        final body = await bytes;
        if (!hasListeners) return;
        final memory = MemoryImage(body);
        final stream = memory.loadImage(memory, decode);
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (image, _) {
            setImage(image.clone());
            image.dispose();
          },
          onError: (Object error, StackTrace? stack) => reportError(
            context: ErrorDescription('loading an authenticated image'),
            exception: error,
            stack: stack,
          ),
        );
        stream.addListener(listener);
        addOnLastListenerRemovedCallback(() => stream.removeListener(listener));
      } catch (error, stack) {
        reportError(
          context: ErrorDescription('loading an authenticated image'),
          exception: error,
          stack: stack,
        );
      } finally {
        pending.dispose();
      }
    }());
  }
}
