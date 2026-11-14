import 'package:cloud_board/src/app/core/widgets/preparation_stage_status.dart';
import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_motion.dart';
import 'package:cloud_board/src/app/core/widgets/motion/app_content_transition.dart';

class AsyncActionOverlay extends StatelessWidget {
  const AsyncActionOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.label,
  });

  final bool isLoading;
  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      AbsorbPointer(absorbing: isLoading, child: child),
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.stateChange),
            color: isLoading ? const Color(0x33000000) : Colors.transparent,
          ),
        ),
      ),
      if (isLoading)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: label != null
                  ? Material(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: PreparationStageStatus(label: label!),
                        ),
                      ),
                    )
                  : Semantics(
                      liveRegion: true,
                      label: '처리 중',
                      child: ExcludeSemantics(
                        child: AppContentTransition(
                          transitionKey: isLoading,
                          animateOnMount: true,
                          child: AppMotion.reduced(context)
                              ? const Icon(Icons.hourglass_empty_rounded)
                              : const CircularProgressIndicator(),
                        ),
                      ),
                    ),
            ),
          ),
        ),
    ],
  );
}
