import 'package:flutter/material.dart';

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
  });

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
          WorkoutImage(
            source: module.imageSource,
            fit: module.coverImage ? BoxFit.cover : BoxFit.contain,
            showLoadingIndicator: showLoadingIndicator,
          )
        else
          const ColoredBox(color: Colors.black),
        SafeArea(
          minimum: EdgeInsets.all(20 * scale),
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
                if (module.showSets) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${remainingSets(set: set, total: totalSets, isRest: isRest)}/$totalSets세트',
                      key: const ValueKey('slide-sets'),
                      style: TextStyle(
                        color: Color(module.appearance.setsColor),
                        fontSize: 22 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                ],
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
        if (module.showTimer)
          // Anchor to the slide, so title wrapping and set labels cannot move it.
          Positioned(
            left:
                (constraints.maxWidth * module.appearance.timerX).clamp(
                  116 * scale * module.appearance.timerSize,
                  constraints.maxWidth -
                      116 * scale * module.appearance.timerSize,
                ) -
                116 * scale * module.appearance.timerSize,
            top:
                (constraints.maxHeight * module.appearance.timerY).clamp(
                  116 * scale * module.appearance.timerSize,
                  constraints.maxHeight -
                      116 * scale * module.appearance.timerSize,
                ) -
                116 * scale * module.appearance.timerSize,
            child: _CircularTimer(
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
            ),
          ),
      ],
    ),
  );
}

class _CircularTimer extends StatelessWidget {
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
            Center(
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
          ],
        ),
      ),
    );
  }
}
