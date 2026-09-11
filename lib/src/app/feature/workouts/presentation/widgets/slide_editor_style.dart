import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';

/// Existing editor callers share the same application-wide palette and controls.
abstract final class SlideEditorStyle {
  static const ink = AppColors.ink;
  static const muted = AppColors.muted;
  static const accent = AppColors.accent;
  static const surface = AppColors.surface;
  static const wheel = AppColors.selected;
  static const line = AppColors.line;

  static ThemeData theme(ThemeData base) => AppTheme.apply(base);
}
