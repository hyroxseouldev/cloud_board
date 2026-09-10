import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';

/// Bounded reuse also gives MemoryImage a stable key across preview and playback.
class WorkoutImageBytesCache {
  WorkoutImageBytesCache({this.maximumBytes = 16 * 1024 * 1024});
  final int maximumBytes;
  final _entries = <String, Uint8List>{};
  int _bytes = 0;

  Uint8List decode(String source) {
    final cached = _entries.remove(source);
    if (cached != null) {
      _entries[source] = cached;
      return cached;
    }
    final bytes = WorkoutImageSource.decode(source).bytes;
    // Include retained Base64 text in the budget, conservatively at two bytes
    // per character. Oversize images are retained only by their visible widget.
    final cost = bytes.length + source.length * 2;
    if (cost > maximumBytes) return bytes;
    while (_bytes + cost > maximumBytes && _entries.isNotEmpty) {
      final key = _entries.keys.first;
      _bytes -= _entries.remove(key)!.length + key.length * 2;
    }
    _entries[source] = bytes;
    _bytes += cost;
    return bytes;
  }
}

final _bytesCache = WorkoutImageBytesCache();

typedef WorkoutImageSize = ({int? width, int? height});

WorkoutImageSize workoutImageSize(Size logicalSize, double pixelRatio) {
  int? dimension(double value) => value.isFinite && value > 0
      ? ((value * pixelRatio / 128).ceil() * 128).clamp(128, 3840)
      : null;
  return (
    width: dimension(logicalSize.width),
    height: dimension(logicalSize.height),
  );
}

WorkoutImageSize playbackImageSize(BuildContext context) {
  final viewport = MediaQuery.sizeOf(context);
  final width = viewport.width < viewport.height * 16 / 9
      ? viewport.width
      : viewport.height * 16 / 9;
  return workoutImageSize(
    Size(width, width * 9 / 16),
    MediaQuery.devicePixelRatioOf(context),
  );
}

ImageProvider workoutImageProvider(String source, WorkoutImageSize size) {
  final remote = source.startsWith('https://') || source.startsWith('http://');
  final ImageProvider provider = remote
      ? kIsWeb
            ? NetworkImage(
                source,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              )
            : CachedNetworkImageProvider(source)
      : MemoryImage(_bytesCache.decode(source));
  // HTML network images use the browser's decoding/rendering path.
  if ((kIsWeb && remote) || (size.width == null && size.height == null)) {
    return provider;
  }
  return ResizeImage(
    provider,
    width: size.width,
    height: size.height,
    policy: ResizeImagePolicy.fit,
  );
}

/// Bounded concurrency avoids decoding an entire workout at once. Shared URLs
/// are fetched once; cancelled screens do not start more requests.
Future<int> warmWorkoutImages(
  Iterable<String> sources, {
  required Future<void> Function(String source) load,
  bool Function()? isCancelled,
  int concurrency = 3,
}) async {
  assert(concurrency > 0);
  final queue = sources.where((source) => source.isNotEmpty).toSet().toList();
  var next = 0;
  var loaded = 0;
  Future<void> worker() async {
    while (next < queue.length && !(isCancelled?.call() ?? false)) {
      final source = queue[next++];
      await load(source);
      loaded++;
    }
  }

  await Future.wait(List.generate(concurrency, (_) => worker()));
  return loaded;
}

Future<int> precacheWorkoutImages(
  BuildContext context,
  Iterable<String> sources, {
  bool Function()? isCancelled,
}) {
  final size = playbackImageSize(context);
  return warmWorkoutImages(
    sources,
    isCancelled: () => !context.mounted || (isCancelled?.call() ?? false),
    load: (source) async {
      Object? failure;
      final loading = precacheImage(
        workoutImageProvider(source, size),
        context,
        onError: (error, stack) => failure = error,
      );
      if (source.startsWith('http://') || source.startsWith('https://')) {
        await loading.timeout(const Duration(seconds: 20));
      } else {
        await loading;
      }
      if (failure != null) throw failure!;
    },
  );
}
