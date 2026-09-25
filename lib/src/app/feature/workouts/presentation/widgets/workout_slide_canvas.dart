import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

class WorkoutSlideCanvas extends StatelessWidget {
  const WorkoutSlideCanvas({
    super.key,
    required this.module,
    required this.isRest,
    required this.secondsLeft,
    required this.remainingMs,
    required this.durationMs,
    required this.set,
    required this.totalSets,
    required this.isPaused,
    required this.brandL,
    required this.brandR,
    required this.scale,
    this.showLoadingIndicator = false,
    this.timer,
    this.displayPreferences = const DisplayPreferences(),
  });

  final Widget? timer;
  final DisplayPreferences displayPreferences;
  DisplayPreferences get preferences => displayPreferences.enabled
      ? displayPreferences
      : const DisplayPreferences();
  final WorkoutModule module;
  final bool isRest;
  final int secondsLeft;
  final int remainingMs;
  final int durationMs;
  final int set;
  final int totalSets;
  final bool isPaused;
  final String brandL;
  final String brandR;
  final double scale;
  final bool showLoadingIndicator;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        if (module.imageSource.isNotEmpty)
          RepaintBoundary(
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(
                  constraints.maxWidth * preferences.offsetX,
                  constraints.maxHeight * preferences.offsetY,
                ),
                child: Transform.scale(
                  scale: preferences.zoom,
                  child: WorkoutImage(
                    source: module.imageSource,
                    fit:
                        (preferences.enabled
                            ? preferences.cover
                            : module.coverImage)
                        ? BoxFit.cover
                        : BoxFit.contain,
                    resolutionScale: preferences.zoom,
                    showLoadingIndicator: showLoadingIndicator,
                  ),
                ),
              ),
            ),
          )
        else
          const ColoredBox(color: Colors.black),
        SafeArea(
          minimum: EdgeInsets.symmetric(
            horizontal:
                20 * scale + constraints.maxWidth * preferences.safeInset,
            vertical:
                20 * scale + constraints.maxHeight * preferences.safeInset,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              28 * scale,
              28 * scale,
              28 * scale,
              20 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (module.appearance.showTitle)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isRest ? '휴식' : module.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(module.appearance.titleColor),
                            fontSize: 36 * scale,
                            fontWeight: FontWeight.w900,
                            shadows: const [Shadow(blurRadius: 12)],
                          ),
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        !module.appearance.showBody
                            ? ''
                            : isRest
                            ? (module.showSets
                                  ? '다음: ${set + 1}세트'
                                  : '다음 운동을 준비하세요')
                            : module.text,
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(module.appearance.bodyColor),
                          fontSize: 40 * scale,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          shadows: const [Shadow(blurRadius: 12)],
                        ),
                      ),
                    ),
                    if (module.showTimer)
                      Expanded(flex: 2, child: SizedBox(height: 260 * scale)),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        module.appearance.showBrand ? brandL : '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(module.appearance.brandColor),
                          fontSize: 20 * scale,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        module.appearance.showBrand ? brandR : '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Color(module.appearance.brandColor),
                          fontSize: 20 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (module.showTimer || module.showSets)
          _TimerGroup(
            module: module,
            scale: scale,
            preferences: preferences,
            constraints: constraints,
            timer: module.showTimer
                ? RepaintBoundary(
                    child:
                        timer ??
                        WorkoutSlideTimer(
                          module: module,
                          isRest: isRest,
                          secondsLeft: secondsLeft,
                          remainingMs: remainingMs,
                          durationMs: durationMs,
                          isPaused: isPaused,
                          scale: scale,
                        ),
                  )
                : null,
            sets: module.showSets
                ? Text(
                    '${remainingSets(set: set, total: totalSets, isRest: isRest)}/$totalSets세트',
                    key: const ValueKey('slide-sets'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(module.appearance.setsColor),
                      fontSize: 28 * scale * module.appearance.timerSize,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
      ],
    ),
  );
}

/// The timer and set label share a single clamped anchor, including when hidden.
class _TimerGroup extends StatelessWidget {
  const _TimerGroup({
    required this.module,
    required this.scale,
    required this.preferences,
    required this.constraints,
    this.timer,
    this.sets,
  });
  final WorkoutModule module;
  final double scale;
  final DisplayPreferences preferences;
  final BoxConstraints constraints;
  final Widget? timer, sets;
  @override
  Widget build(BuildContext context) {
    final unit = scale * module.appearance.timerSize;
    final width = 232 * unit;
    final timerHeight = timer == null ? 0.0 : width;
    final labelHeight = sets == null ? 0.0 : 40 * unit;
    final height = timerHeight + labelHeight;
    final insetX = constraints.maxWidth * preferences.safeInset;
    final insetY = constraints.maxHeight * preferences.safeInset;
    final anchorX =
        insetX + module.appearance.timerX * (constraints.maxWidth - 2 * insetX);
    final anchorY =
        insetY +
        module.appearance.timerY * (constraints.maxHeight - 2 * insetY);
    final left = (anchorX - width / 2).clamp(
      insetX,
      (constraints.maxWidth - insetX - width).clamp(insetX, double.infinity),
    );
    // Reserve the brand footer rather than allowing the set label to overlap it.
    final maxTop = (constraints.maxHeight - insetY - height - 64 * scale).clamp(
      insetY,
      double.infinity,
    );
    final top = (anchorY - timerHeight / 2).clamp(insetY, maxTop);
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?timer,
          if (sets != null)
            SizedBox(
              height: labelHeight,
              child: Center(child: FittedBox(child: sets!)),
            ),
        ],
      ),
    );
  }
}

class WorkoutSlideTimer extends StatelessWidget {
  const WorkoutSlideTimer({
    super.key,
    required this.module,
    required this.isRest,
    required this.secondsLeft,
    required this.remainingMs,
    required this.durationMs,
    required this.isPaused,
    required this.scale,
  });
  final WorkoutModule module;
  final bool isRest;
  final int secondsLeft, remainingMs, durationMs;
  final bool isPaused;
  final double scale;

  @override
  Widget build(BuildContext context) => _CircularTimer(
    showGauge: module.showTimerGauge,
    secondsLeft: secondsLeft,
    remainingMs: remainingMs,
    durationMs: durationMs,
    isPaused: isPaused,
    gaugeColor: slideColor(
      module,
      rest: isRest,
      text: false,
      secondsLeft: secondsLeft,
    ),
    textColor: slideColor(
      module,
      rest: isRest,
      text: true,
      secondsLeft: secondsLeft,
    ),
    scale: scale * module.appearance.timerSize,
    ringWidth: module.appearance.ringWidth,
  );
}

class _CircularTimer extends HookWidget {
  const _CircularTimer({
    required this.showGauge,
    required this.secondsLeft,
    required this.remainingMs,
    required this.durationMs,
    required this.isPaused,
    required this.gaugeColor,
    required this.textColor,
    required this.scale,
    required this.ringWidth,
  });

  final bool showGauge;
  final int secondsLeft;
  final int remainingMs;
  final int durationMs;
  final bool isPaused;
  final int gaugeColor;
  final int textColor;
  final double scale;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    final timeLabel = useMemoized(
      () => Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(40 * scale),
            child: Text(
              durationLabel(secondsLeft),
              key: const ValueKey('slide-time-text'),
              style: TextStyle(
                color: Color(textColor),
                fontSize: 56 * scale,
                fontWeight: FontWeight.w700,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
      [secondsLeft, textColor, scale],
    );
    final progress = durationMs <= 0
        ? 0.0
        : (remainingMs / durationMs).clamp(0.0, 1.0);
    return Semantics(
      label: '남은 시간 ${durationLabel(secondsLeft)}',
      child: SizedBox.square(
        key: const ValueKey('slide-timer'),
        dimension: 232 * scale,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showGauge)
              TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: isPaused
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                curve: Curves.linear,
                builder: (context, animatedProgress, child) =>
                    CircularProgressIndicator(
                      key: const ValueKey('slide-gauge'),
                      value: animatedProgress,
                      strokeWidth: ringWidth * scale,
                      strokeAlign: CircularProgressIndicator.strokeAlignInside,
                      strokeCap: StrokeCap.butt,
                      trackGap: 0,
                      padding: EdgeInsets.zero,
                      backgroundColor: Color(gaugeColor).withValues(alpha: 0.3),
                      color: Color(gaugeColor),
                    ),
              ),
            timeLabel,
          ],
        ),
      ),
    );
  }
}
