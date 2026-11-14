import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';

/// Decorative home artwork using summary metadata only, never class media.
class WorkoutIconTile extends StatelessWidget {
  const WorkoutIconTile({
    super.key,
    required this.workoutId,
    required this.moduleCount,
    required this.size,
  });

  final String workoutId;
  final int moduleCount;
  final double size;

  static const _palettes = [
    (AppColors.surfaceAccent, AppColors.accent),
    (Color(0xFFE9E4DA), Color(0xFF79674D)),
    (Color(0xFFE1E8EB), Color(0xFF536D7A)),
    (Color(0xFFE9E3EC), Color(0xFF75617D)),
  ];

  @override
  Widget build(BuildContext context) {
    // Explicit stable hashing keeps the same artwork after reloads and sorting.
    final seed = workoutId.codeUnits.fold<int>(
      0,
      (value, unit) => (value * 31 + unit) & 0x7fffffff,
    );
    final (background, foreground) = _palettes[seed % _palettes.length];
    final icon = moduleCount == 0
        ? Icons.dashboard_outlined
        : moduleCount == 1
        ? Icons.slideshow_rounded
        : Icons.view_carousel_rounded;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ColoredBox(
            color: background,
            child: Stack(
              children: [
                Positioned(
                  top: -size * .32,
                  right: -size * .24,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: foreground.withValues(alpha: .09),
                        width: size * .17,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: size * .13,
                  bottom: size * .13,
                  child: Container(
                    width: size * .22,
                    height: size * .05,
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(size),
                    ),
                  ),
                ),
                Center(
                  child: Icon(icon, size: size * .48, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
