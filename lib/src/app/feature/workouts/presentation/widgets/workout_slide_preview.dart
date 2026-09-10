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
  });

  final WorkoutModule module;
  final bool isRest;
  final String brandL;
  final String brandR;

  @override
  Widget build(BuildContext context) {
    final seconds = isRest ? module.restSeconds : module.workSeconds;
    final durationMs = seconds * 1000;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
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
                  isRest: isRest,
                  secondsLeft: seconds,
                  remainingMs: durationMs,
                  durationMs: durationMs,
                  set: 1,
                  totalSets: module.sets,
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
