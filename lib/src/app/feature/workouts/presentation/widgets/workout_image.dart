import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';

class WorkoutImage extends StatelessWidget {
  const WorkoutImage({
    super.key,
    required this.source,
    required this.fit,
    this.showLoadingIndicator = false,
  });

  final String source;
  final BoxFit fit;
  final bool showLoadingIndicator;

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('https://') || source.startsWith('http://')) {
      if (kIsWeb) {
        return Image.network(
          source,
          fit: fit,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          loadingBuilder: showLoadingIndicator
              ? (context, child, progress) {
                  if (progress == null) return child;
                  final expectedBytes = progress.expectedTotalBytes;
                  return Center(
                    child: CircularProgressIndicator(
                      value: expectedBytes == null
                          ? null
                          : progress.cumulativeBytesLoaded / expectedBytes,
                    ),
                  );
                }
              : null,
          errorBuilder: (context, error, stackTrace) => const _BrokenImage(),
        );
      }
      return CachedNetworkImage(
        imageUrl: source,
        fit: fit,
        progressIndicatorBuilder: showLoadingIndicator
            ? (context, url, progress) => Center(
                child: CircularProgressIndicator(value: progress.progress),
              )
            : null,
        errorWidget: (context, url, error) => const _BrokenImage(),
      );
    }

    try {
      return Image.memory(
        WorkoutImageSource.decode(source).bytes,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => const _BrokenImage(),
      );
    } on FormatException {
      return const _BrokenImage();
    }
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48),
  );
}
