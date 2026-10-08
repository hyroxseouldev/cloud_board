import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';

class WorkoutSlidePreview extends StatelessWidget {
  const WorkoutSlidePreview({
    super.key,
    required this.module,
    required this.isRest,
    this.brandL = '',
    this.brandR = '',
    this.borderRadius = 12,
  });

  final double borderRadius;
  final WorkoutModule module;
  final bool isRest;
  final String brandL;
  final String brandR;

  @override
  Widget build(BuildContext context) {
    final phases = workoutModuleTimeline(module);
    final phase =
        phases.where((p) => p.isRest == isRest).firstOrNull ??
        phases.firstOrNull;
    final seconds = phase?.seconds ?? 0;
    final durationMs = seconds * 1000;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = constraints.maxWidth / 1280;
              return MediaQuery.removePadding(
                context: context,
                removeLeft: true,
                removeTop: true,
                removeRight: true,
                removeBottom: true,
                child: WorkoutSlideCanvas(
                  module: module,
                  isRest: phase?.isRest ?? isRest,
                  secondsLeft: seconds,
                  remainingMs: durationMs,
                  durationMs: durationMs,
                  set: phase?.set ?? 1,
                  totalSets: phase?.totalSets ?? 1,
                  positionLabel: phase == null
                      ? null
                      : workoutPhaseLabel(module, phase),
                  isPaused: true,
                  brandL: brandL,
                  brandR: brandR,
                  scale: scale,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
