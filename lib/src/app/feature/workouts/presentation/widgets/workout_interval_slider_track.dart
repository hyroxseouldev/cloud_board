import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';

typedef WorkoutIntervalSegment = ({int startMs, int endMs, bool isRest});

List<WorkoutIntervalSegment> workoutIntervalSegments(WorkoutModule module) {
  final segments = <WorkoutIntervalSegment>[];
  var offset = 0;
  void add(int seconds, bool isRest) {
    if (seconds <= 0) return;
    final end = offset + seconds * 1000;
    segments.add((startMs: offset, endMs: end, isRest: isRest));
    offset = end;
  }

  for (final block in effectiveIntervalBlocks(module)) {
    for (var set = 0; set < block.sets; set++) {
      add(block.workSeconds, false);
      if (set < block.sets - 1) add(block.restSeconds, true);
    }
  }
  return segments;
}

/// Changes only painting: Slider still owns seeking, focus and accessibility.
class WorkoutIntervalSliderTrack extends RoundedRectSliderTrackShape {
  const WorkoutIntervalSliderTrack({
    required this.segments,
    required this.positionMs,
    required this.maxMs,
  });

  final List<WorkoutIntervalSegment> segments;
  final int positionMs;
  final double maxMs;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final start = (segment.startMs / math.max(1, maxMs)).clamp(0.0, 1.0);
      final end = (segment.endMs / math.max(1, maxMs)).clamp(0.0, 1.0);
      final width = (end - start) * rect.width;
      if (width <= 0) continue;
      // Keep short intervals visible without expanding their time hit area.
      final gap = math.min(3.0, width / 3);
      final left =
          rect.left +
          (textDirection == TextDirection.ltr ? start : 1 - end) * rect.width;
      final current =
          positionMs >= segment.startMs &&
          (positionMs < segment.endMs || i == segments.length - 1);
      final height = current ? 8.0 : 6.0;
      final color = current
          ? AppColors.accent
          : segment.isRest
          ? AppColors.selected
          : AppColors.accent.withValues(alpha: .4);
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left + gap / 2,
            rect.center.dy - height / 2,
            width - gap,
            height,
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = Color.lerp(
            AppColors.selected,
            color,
            enableAnimation.value,
          )!,
      );
    }
  }
}
