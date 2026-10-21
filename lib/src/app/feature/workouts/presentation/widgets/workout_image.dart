import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/core/theme/app_motion.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';

class WorkoutImage extends StatelessWidget {
  const WorkoutImage({
    super.key,
    required this.source,
    required this.fit,
    this.showLoadingIndicator = false,
    this.preview = false,
    this.onError,
    this.resolutionScale = 1,
    this.webHtmlElementStrategy = WebHtmlElementStrategy.prefer,
  });

  final WebHtmlElementStrategy webHtmlElementStrategy;
  final double resolutionScale;
  final String source;
  final BoxFit fit;
  final bool showLoadingIndicator;
  final bool preview;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = workoutImageSize(
        constraints.biggest,
        MediaQuery.devicePixelRatioOf(context) * resolutionScale,
      );
      return _SizedWorkoutImage(
        // Changed source/version/decode bounds dispose any old retry response.
        key: preview ? ValueKey((source, size, webHtmlElementStrategy)) : null,
        preview: preview,
        source: source,
        fit: fit,
        size: size,
        showLoadingIndicator: showLoadingIndicator,
        onError: onError,
        webHtmlElementStrategy: webHtmlElementStrategy,
      );
    },
  );
}

class _SizedWorkoutImage extends HookWidget {
  const _SizedWorkoutImage({
    super.key,
    required this.preview,
    required this.source,
    required this.fit,
    required this.size,
    required this.showLoadingIndicator,
    required this.onError,
    required this.webHtmlElementStrategy,
  });
  final bool preview;
  final String source;
  final BoxFit fit;
  final WorkoutImageSize size;
  final bool showLoadingIndicator;
  final VoidCallback? onError;
  final WebHtmlElementStrategy webHtmlElementStrategy;

  @override
  Widget build(BuildContext context) {
    final attempt = useState(0);
    final retrying = useState(false);
    final provider = useMemoized(() {
      try {
        return workoutImageProvider(
          source,
          size,
          webHtmlElementStrategy: webHtmlElementStrategy,
        );
      } on FormatException {
        return null;
      }
    }, [source, size, webHtmlElementStrategy, attempt.value]);
    Future<void> retry() async {
      if (retrying.value) return;
      retrying.value = true;
      try {
        // Evict only this failed decoded provider. Native disk cache, URL/query
        // version and browser HTTP revalidation stay on their existing paths.
        await provider?.evict();
      } catch (_) {
        // Resolve once more even if the failed key was already removed.
      } finally {
        if (context.mounted) {
          retrying.value = false;
          attempt.value++;
        }
      }
    }

    Widget error() {
      onError?.call();
      if (preview) {
        return WorkoutImageFailure(onRetry: retrying.value ? null : retry);
      }
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
      key: preview ? ValueKey((source, size, attempt.value)) : null,
      image: provider,
      // A synchronous ImageCache hit paints immediately. Wait only for a first
      // decoded frame (including HTML fallback); never re-fade cached images.
      frameBuilder: preview
          ? (context, child, frame, synchronous) => synchronous || frame != null
                ? child
                : const WorkoutImageSkeleton()
          : null,
      fit: fit,
      loadingBuilder: !preview && showLoadingIndicator
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

/// Fills the already constrained image area without changing fit or clip bounds.
class WorkoutImageSkeleton extends HookWidget {
  const WorkoutImageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final lifecycle = useAppLifecycleState();
    final animate =
        !AppMotion.reduced(context) &&
        TickerMode.valuesOf(context).enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    final pulse = useAnimationController(
      duration: AppMotion.shimmer,
      initialValue: 1,
    );
    useEffect(() {
      if (animate) {
        pulse.repeat(reverse: true);
      } else {
        pulse.stop();
        pulse.value = 1;
      }
      return null;
    }, [animate, pulse]);
    return Semantics(
      label: '이미지 불러오는 중',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: FadeTransition(
            opacity: Tween<double>(
              begin: .5,
              end: 1,
            ).animate(pulse.drive(CurveTween(curve: Curves.easeInOut))),
            child: const SizedBox.expand(
              key: ValueKey('workout-image-skeleton'),
              child: ColoredBox(
                color: Color(0x227A887C),
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: .55,
                    heightFactor: .12,
                    child: ColoredBox(color: Color(0x227A887C)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkoutImageFailure extends StatelessWidget {
  const WorkoutImageFailure({super.key, required this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      // Thumbnails keep the same footprint, with an accessible retry tooltip.
      if (bounds.maxWidth < 240 || bounds.maxHeight < 120) {
        return Center(
          child: IconButton(
            key: const ValueKey('workout-image-retry'),
            tooltip: '이미지를 불러오지 못했어요 · 다시 시도',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined),
            const SizedBox(height: 8),
            const Text('이미지를 불러오지 못했어요.', textAlign: TextAlign.center),
            TextButton(
              key: const ValueKey('workout-image-retry'),
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    },
  );
}
