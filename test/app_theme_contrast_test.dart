import 'dart:math' as math;

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

void main() {
  test('management text remains readable on every shared surface', () {
    for (final background in [
      AppColors.canvas,
      AppColors.surface,
      AppColors.selected,
      AppColors.navigation,
    ]) {
      for (final foreground in [
        AppColors.ink,
        AppColors.muted,
        AppColors.accent,
      ]) {
        expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
      }
    }
    expect(
      contrast(AppColors.onAccent, AppColors.accent),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('input boundaries remain distinguishable from canvas and surface', () {
    for (final background in [AppColors.canvas, AppColors.surface]) {
      expect(
        contrast(AppColors.controlBorder, background),
        greaterThanOrEqualTo(3),
      );
    }
  });
}
