import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/widgets/motion/app_content_transition.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:flutter/material.dart';

class MiniClassBar extends StatelessWidget {
  const MiniClassBar({
    super.key,
    required this.title,
    required this.label,
    required this.imageSource,
    required this.progress,
    required this.paused,
    required this.onExpand,
    this.onToggle,
    this.onPrevious,
    this.onNext,
    this.onRetry,
  });

  final String title;
  final String label;
  final String imageSource;
  final double progress;
  final bool paused;
  final VoidCallback onExpand;
  final VoidCallback? onToggle;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('mini-class-bar'),
    color: AppColors.selected.withValues(alpha: .65),
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          key: const ValueKey('mini-class-progress'),
          value: progress,
          minHeight: 3,
          stopIndicatorRadius: 0,
          trackGap: 0,
          color: AppColors.accent,
          backgroundColor: AppColors.selected,
          semanticsLabel: '전체 수업 진행률',
          semanticsValue: '${(progress * 100).round()}%',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
            final showImage = constraints.maxWidth >= 350 || !largeText;
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('expand-class'),
                      onTap: onExpand,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                        child: Row(
                          children: [
                            if (showImage) ...[
                              ExcludeSemantics(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox.square(
                                    dimension: 44,
                                    child: imageSource.isEmpty
                                        ? const ColoredBox(
                                            color: AppColors.selected,
                                            child: Icon(
                                              Icons.slideshow_outlined,
                                            ),
                                          )
                                        : WorkoutImage(
                                            source: imageSource,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    maxLines: largeText ? 3 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (constraints.maxWidth >= 600)
                    IconButton(
                      tooltip: '이전 슬라이드',
                      onPressed: onPrevious,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                  if (onRetry != null)
                    IconButton(
                      tooltip: '다시 연결',
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                    )
                  else
                    IconButton.filled(
                      tooltip: paused ? '수업 재개' : '수업 일시정지',
                      onPressed: onToggle,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      icon: AppContentTransition(
                        transitionKey: paused,
                        child: Icon(
                          paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                      ),
                    ),
                  if (constraints.maxWidth >= 600)
                    IconButton(
                      tooltip: '다음 슬라이드',
                      onPressed: onNext,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  IconButton(
                    tooltip: '수업으로 돌아가기',
                    onPressed: onExpand,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}
