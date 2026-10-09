import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

class WorkoutSlideListCard extends StatelessWidget {
  const WorkoutSlideListCard({
    super.key,
    required this.module,
    required this.index,
    required this.menu,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
    this.brandL = '',
    this.brandR = '',
  });

  final WorkoutModule module;
  final int index;
  final Widget menu;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final String brandL;
  final String brandR;

  static double extent(TextScaler textScaler) => 100 * textScaler.scale(1);

  String get _timingLabel {
    final blocks = effectiveIntervalBlocks(module);
    if (isContinuousTimer(module)) {
      return '${timerModeLabel(module.timerMode)} · ${moduleDurationText(module)}';
    }
    if (hasRoundTiming(module)) {
      return '${module.rounds}라운드 · ${blocks.length}블록 · 라운드 휴식 ${formatSlideTime(module.roundRestSeconds)}';
    }
    if (blocks.length != 1) {
      return '${blocks.length}블록 · 총 ${moduleDurationText(module)}';
    }
    final block = blocks.single;
    return block.workSeconds == 0
        ? '휴식만 ${formatSlideTime(block.restSeconds)} · ${block.sets}회'
        : '${block.sets}세트 · ${formatSlideTime(block.workSeconds)} / 휴식 ${formatSlideTime(block.restSeconds)}';
  }

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: selected ? AppColors.selected : AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? AppColors.accent : AppColors.line),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
          child: LayoutBuilder(
            builder: (context, bounds) => Row(
              children: [
                ReorderableDragStartListener(
                  key: ValueKey('slide-drag-${module.id}'),
                  index: index,
                  enabled: enabled,
                  child: Tooltip(
                    message: '드래그하여 순서 변경',
                    child: MouseRegion(
                      cursor: enabled
                          ? SystemMouseCursors.grab
                          : SystemMouseCursors.basic,
                      child: Container(
                        color: Colors.transparent,
                        width: 44,
                        height: 48,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.drag_handle,
                          size: 20,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: (bounds.maxWidth * .21).clamp(56.0, 112.0),
                  child: RepaintBoundary(
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: MediaQuery.withClampedTextScaling(
                          minScaleFactor: 1,
                          maxScaleFactor: 1,
                          child: WorkoutSlidePreview(
                            module: module,
                            isRest: false,
                            brandL: brandL,
                            brandR: brandR,
                            borderRadius: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.name.isEmpty ? '슬라이드 ${index + 1}' : module.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timingLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bounds.maxWidth * .3),
                  child: Text(
                    moduleDurationText(module),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                menu,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
