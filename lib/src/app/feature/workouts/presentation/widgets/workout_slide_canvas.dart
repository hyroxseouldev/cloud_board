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
  Widget build(BuildContext context) => Stack(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isRest ? '휴식' : module.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
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
                      isRest
                          ? (module.showSets
                                ? '다음: ${set + 1}세트'
                                : '다음 운동을 준비하세요')
                          : module.text,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40 * scale,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        shadows: const [Shadow(blurRadius: 12)],
                      ),
                    ),
                  ),
                  if (module.showTimer)
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
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
                          scale: scale,
                        ),
                      ),
                    ),
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
                      color: Colors.white70,
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
                      brandL,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20 * scale,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      brandR,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white70,
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
    ],
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
  });

  final bool showGauge;
  final int secondsLeft;
  final int remainingMs;
  final int durationMs;
  final bool isPaused;
  final int gaugeColor;
  final int textColor;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final progress = durationMs <= 0
        ? 0.0
        : (remainingMs / durationMs).clamp(0.0, 1.0);
    return Semantics(
      label: '남은 시간 ${durationLabel(secondsLeft)}',
      child: SizedBox.square(
        key: const ValueKey('slide-timer'),
        dimension: 260 * scale,
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
                      strokeWidth: 18 * scale,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white24,
                      color: Color(gaugeColor),
                    ),
              ),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.all(28 * scale),
                  child: Text(
                    durationLabel(secondsLeft),
                    key: const ValueKey('slide-time-text'),
                    style: TextStyle(
                      color: Color(textColor),
                      fontSize: 64 * scale,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3 * scale,
                      shadows: const [Shadow(blurRadius: 20)],
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
