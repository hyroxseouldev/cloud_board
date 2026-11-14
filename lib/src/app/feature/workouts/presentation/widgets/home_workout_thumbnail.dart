import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/home_thumbnail_loader.dart';

/// Image only: no slide canvas, countdown, timer, player or workout-detail read.
class HomeWorkoutThumbnail extends HookConsumerWidget {
  const HomeWorkoutThumbnail({
    super.key,
    required this.ownerId,
    required this.workout,
    this.width = 108,
  });
  final String ownerId;
  final WorkoutSummary workout;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(homeThumbnailCacheProvider(ownerId));
    final active = TickerMode.valuesOf(context).enabled;
    final request = useMemoized(
      () => !active
          ? null
          : cache.watch(
              workout.imageSource,
              workout.updatedAt,
              workoutId: workout.id,
            ),
      [
        cache,
        ownerId,
        workout.id,
        workout.imageSource,
        workout.updatedAt,
        active,
      ],
    );
    useEffect(() => request?.release, [request]);
    final result = useFuture(request?.future, preserveState: false);
    const placeholder = Center(
      child: Icon(Icons.image_outlined, size: 24, color: AppColors.muted),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: AppColors.surfaceAccent,
              child: result.data == null
                  ? placeholder
                  : Image.memory(
                      result.data!,
                      key: ValueKey((
                        ownerId,
                        workout.imageSource,
                        workout.updatedAt,
                      )),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      cacheWidth: 192,
                      gaplessPlayback: false,
                      frameBuilder: (_, child, frame, synchronous) =>
                          synchronous || frame != null ? child : placeholder,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
