import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shadcn;

import 'package:cloud_board/src/app/core/theme/app_colors.dart';

/// Installs only page-local component infrastructure; the app's Material theme,
/// Navigator, account providers and route lifecycle remain outside this scope.
class HomeShadcnScope extends StatelessWidget {
  const HomeShadcnScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Localizations.override(
    context: context,
    delegates: const [shadcn.GlobalShadLocalizations.delegate],
    child: shadcn.ShadTheme(
      data: shadcn.ShadThemeData(
        brightness: Brightness.light,
        radius: BorderRadius.circular(12),
        textTheme: shadcn.ShadTextTheme(family: 'Pretendard'),
        colorScheme: const shadcn.ShadZincColorScheme.light().copyWith(
          background: AppColors.canvas,
          foreground: AppColors.ink,
          card: AppColors.surface,
          cardForeground: AppColors.ink,
          primary: AppColors.accent,
          primaryForeground: AppColors.onAccent,
          secondary: AppColors.selected,
          secondaryForeground: AppColors.accent,
          muted: AppColors.navigation,
          mutedForeground: AppColors.muted,
          accent: AppColors.selected,
          accentForeground: AppColors.ink,
          border: AppColors.line,
          input: AppColors.controlBorder,
          ring: AppColors.accent,
        ),
      ),
      child: shadcn.ShadAppBuilder(child: child),
    ),
  );
}
