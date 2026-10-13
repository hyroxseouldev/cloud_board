import 'dart:math' as math;

/// Role-based upper bounds in the shared 1920×1080 design coordinate space.
/// Fit from these limits; never multiply an already-fitted dense layout by a
/// scale factor. Original raster templates and live timer geometry are separate.
abstract final class SlideDesignTypography {
  static const minimumReadable = 36.0;
  static const bodyMax = 92.0;
  static const cardBodyMax = 86.0;
  static const legacyTitleMax = 86.0;
  static double legacyBodyMax(int columns) => columns == 1 ? 64 : 52;

  static double titleMax(String family) => switch (family) {
    'editorial' => 110,
    'focus' => 94,
    'cards' => 76,
    _ => 84,
  };
  static double subtitleMax(String family) => family == 'cards' ? 44 : 48;
  static double headerLabelMax(String family) => family == 'banner' ? 40 : 38;

  static const headerHeightMax = 120.0;
  static const titleLabelGap = 28.0;
  static const subtitleGap = 30.0;
  static double bodyTopGap(String family) => switch (family) {
    'banner' => 48,
    'editorial' => 36,
    _ => 32,
  };
  static const sectionScale = 1.04;
  static const badgeScale = 1.16;
  static const numberScale = .76;
  static const badgeTextGap = 28.0;
  static const cardPadding = 24.0;
  static const columnGap = 36.0;

  /// Preserve the user's spacing preference without spreading a short list
  /// across the entire canvas. Line height also retains designSpacing.
  static double maxRowGap(double spacing) =>
      math.min(48, 40 * spacing.clamp(.8, 1.5));
  static double rowGap(double fontSize, String family, double spacing) =>
      math.min(
        maxRowGap(spacing),
        fontSize * (family == 'banner' ? .4 : .28) * spacing.clamp(.8, 1.5),
      );
  static double sectionGap(double fontSize, double spacing) =>
      math.min(48, fontSize * .45 * spacing.clamp(.8, 1.5));
}
