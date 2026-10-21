import 'package:cloud_board/src/app/core/utils/hex_color.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

enum SlideTimerColorTarget { sets, workGauge, restGauge, workText, restText }

/// Apply to the caller's latest module, once; all unrelated fields are retained.
WorkoutModule editSlideTimerColor(
  WorkoutModule latest,
  SlideTimerColorTarget target,
  String color, {
  bool pair = false,
}) => switch (target) {
  SlideTimerColorTarget.sets =>
    parseHexColor(color) == null
        ? latest
        : latest.copyWith(
            appearance: latest.appearance.copyWith(
              setsColor: parseHexColor(color)!,
            ),
          ),
  SlideTimerColorTarget.workGauge => latest.copyWith(
    workGaugeColor: color,
    workTextColor: pair ? color : latest.workTextColor,
  ),
  SlideTimerColorTarget.restGauge => latest.copyWith(
    restGaugeColor: color,
    restTextColor: pair ? color : latest.restTextColor,
  ),
  SlideTimerColorTarget.workText => latest.copyWith(workTextColor: color),
  SlideTimerColorTarget.restText => latest.copyWith(restTextColor: color),
};
