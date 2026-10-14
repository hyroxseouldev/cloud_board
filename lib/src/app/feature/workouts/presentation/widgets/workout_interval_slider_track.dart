import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';

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

  for (final phase in workoutModuleTimeline(module)) {
    add(phase.seconds, phase.isRest);
  }
  return segments;
}

/// Changes only painting: Slider still owns seeking, focus and accessibility.
class WorkoutIntervalSliderTrack extends RoundedRectSliderTrackShape {
  const WorkoutIntervalSliderTrack({
    required this.segments,
    required this.maxMs,
  });

  final List<WorkoutIntervalSegment> segments;
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
    if (rect.isEmpty) return;
    final canvas = context.canvas;
    final split = thumbCenter.dx.clamp(rect.left, rect.right);
    final enabled = enableAnimation.value;
    final active = Color.lerp(
      sliderTheme.disabledActiveTrackColor,
      sliderTheme.activeTrackColor,
      enabled,
    )!;
    final inactive = Color.lerp(
      sliderTheme.disabledInactiveTrackColor,
      sliderTheme.inactiveTrackColor,
      enabled,
    )!;
    final elapsed = textDirection == TextDirection.ltr
        ? Rect.fromLTRB(rect.left, rect.top, split, rect.bottom)
        : Rect.fromLTRB(split, rect.top, rect.right, rect.bottom);

    // Slider owns the animated/dragged thumb position. Splitting at that exact
    // point keeps both sides aligned even during a seek, rollback or RTL layout.
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
    );
    canvas.drawRect(rect, Paint()..color = inactive);
    canvas.drawRect(elapsed, Paint()..color = active);

    // Interval boundaries are secondary to elapsed progress. Avoid dense marks
    // turning very short intervals into another solid, misleading progress bar.
    if (maxMs.isFinite && maxMs > 0) {
      double? previousX;
      for (final segment in segments) {
        if (segment.endMs <= 0 || segment.endMs >= maxMs) continue;
        final fraction = segment.endMs / maxMs;
        final x =
            rect.left +
            (textDirection == TextDirection.ltr ? fraction : 1 - fraction) *
                rect.width;
        if (previousX != null && (x - previousX).abs() < 4) continue;
        previousX = x;
        final isElapsed = textDirection == TextDirection.ltr
            ? x < split
            : x > split;
        final marker = Color.lerp(
          isElapsed
              ? sliderTheme.disabledActiveTickMarkColor
              : sliderTheme.disabledInactiveTickMarkColor,
          isElapsed
              ? sliderTheme.activeTickMarkColor
              : sliderTheme.inactiveTickMarkColor,
          enabled,
        );
        if (marker == null) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            x - .5,
            rect.top + 1,
            1,
            (rect.height - 2).clamp(0, rect.height),
          ),
          Paint()..color = marker,
        );
      }
    }
    canvas.restore();
  }
}
