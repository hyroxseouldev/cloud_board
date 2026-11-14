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

/// The welcome stays in the page scroll, including at accessibility text sizes.
class HomeWelcome extends StatelessWidget {
  const HomeWelcome({super.key, required this.displayName});
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final name = displayName?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? '안녕하세요' : '$name님, 안녕하세요',
            key: const ValueKey('home-greeting'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '좋은 수업을 위한\n모든 준비.',
            key: ValueKey('home-welcome'),
            style: TextStyle(
              fontSize: 30,
              height: 1.3,
              letterSpacing: -.8,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
