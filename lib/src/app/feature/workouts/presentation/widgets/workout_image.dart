import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';

class WorkoutImage extends StatelessWidget {
  const WorkoutImage({
    super.key,
    required this.source,
    required this.fit,
    this.showLoadingIndicator = false,
    this.onError,
  });

  final String source;
  final BoxFit fit;
  final bool showLoadingIndicator;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _SizedWorkoutImage(
      source: source,
      fit: fit,
      size: workoutImageSize(
        constraints.biggest,
        MediaQuery.devicePixelRatioOf(context),
      ),
      showLoadingIndicator: showLoadingIndicator,
      onError: onError,
    ),
  );
}

class _SizedWorkoutImage extends HookWidget {
  const _SizedWorkoutImage({
    required this.source,
    required this.fit,
    required this.size,
    required this.showLoadingIndicator,
    required this.onError,
  });
  final String source;
  final BoxFit fit;
  final WorkoutImageSize size;
  final bool showLoadingIndicator;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    final provider = useMemoized(() {
      try {
        return workoutImageProvider(source, size);
      } on FormatException {
        return null;
      }
    }, [source, size]);
    Widget error() {
      onError?.call();
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 48,
        ),
      );
    }

    if (provider == null) return error();
    return Image(
      image: provider,
      fit: fit,
      loadingBuilder: showLoadingIndicator
          ? (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes == null
                      ? null
                      : progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!,
                ),
              );
            }
          : null,
      errorBuilder: (context, exception, stack) => error(),
    );
  }
}
