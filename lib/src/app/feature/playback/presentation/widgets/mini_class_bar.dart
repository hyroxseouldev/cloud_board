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
    color: AppColors.surfaceAccent,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        final compact =
            MediaQuery.sizeOf(context).height <= 450 ||
            (largeText && constraints.maxWidth < 400);
        final showImage =
            !compact && (constraints.maxWidth >= 350 || !largeText);
        return ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: compact ? (largeText ? 64 : 48) : 88,
          ),
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: compact && constraints.maxWidth < 600
                      ? '수업으로 돌아가기'
                      : '',
                  excludeFromSemantics: true,
                  child: InkWell(
                    key: const ValueKey('expand-class'),
                    onTap: onExpand,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        compact ? (largeText ? 8 : 4) : 14,
                        8,
                        compact ? (largeText ? 8 : 4) : 14,
                      ),
                      child: Row(
                        children: [
                          if (showImage) ...[
                            ExcludeSemantics(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox.square(
                                  dimension: 48,
                                  child: imageSource.isEmpty
                                      ? const ColoredBox(
                                          color: AppColors.surface,
                                          child: Icon(
                                            Icons.slideshow_outlined,
                                            color: AppColors.muted,
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
                                if (compact)
                                  Tooltip(
                                    message: '$title · $label',
                                    excludeFromSemantics: true,
                                    child: Semantics(
                                      label: constraints.maxWidth < 600
                                          ? title
                                          : null,
                                      child: Row(
                                        children: [
                                          if (constraints.maxWidth >= 600) ...[
                                            Expanded(
                                              child: Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  letterSpacing: -.17,
                                                  height: 1.3,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.ink,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          Flexible(
                                            child: Text(
                                              label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.35,
                                                color: AppColors.secondaryText,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else ...[
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      letterSpacing: -.17,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    maxLines: largeText ? 3 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.35,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                                SizedBox(height: compact ? 4 : 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    key: const ValueKey('mini-class-progress'),
                                    value: progress,
                                    minHeight: 4,
                                    stopIndicatorRadius: 0,
                                    trackGap: 0,
                                    color: AppColors.accent,
                                    backgroundColor: AppColors.brandBoardLight
                                        .withValues(alpha: .5),
                                    semanticsLabel: '전체 수업 진행률',
                                    semanticsValue:
                                        '${(progress * 100).round()}%',
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
                    foregroundColor: AppColors.onAccent,
                  ),
                  icon: AppContentTransition(
                    transitionKey: paused,
                    child: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 28,
                    ),
                  ),
                ),
              if (constraints.maxWidth >= 600)
                IconButton(
                  tooltip: '다음 슬라이드',
                  onPressed: onNext,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              if (!compact || constraints.maxWidth >= 600)
                IconButton(
                  tooltip: '수업으로 돌아가기',
                  onPressed: onExpand,
                  icon: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: AppColors.secondaryText,
                  ),
                ),
              const SizedBox(width: 4),
            ],
          ),
        );
      },
    ),
  );
}
