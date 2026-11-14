import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

enum MainDestination {
  home('/', '홈', Icons.home_outlined, Icons.home_rounded),
  library('/slides', '라이브러리', Icons.layers_outlined, Icons.layers_rounded),
  displays(
    '/displays',
    '디스플레이',
    Icons.desktop_windows_outlined,
    Icons.desktop_windows_rounded,
  ),
  more('/more', '더보기', Icons.more_horiz_rounded, Icons.more_horiz_rounded);

  const MainDestination(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  static MainDestination? forPath(String path) {
    for (final destination in values) {
      if (destination.path == path) return destination;
    }
    return null;
  }
}

/// The signed-in shell owns placement and safe areas; this is just the dock.
class MainNavigationDock extends StatelessWidget {
  const MainNavigationDock({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final MainDestination selected;
  final ValueChanged<MainDestination> onSelected;

  // Presentation stays local: routing, tab state and safe areas belong to the
  // existing shell. No ShadApp or overlay host is needed for these buttons.
  @override
  Widget build(BuildContext context) => shad.ShadTheme(
    data: shad.ShadThemeData(
      brightness: Brightness.light,
      radius: BorderRadius.circular(10),
      textTheme: shad.ShadTextTheme(family: 'Pretendard'),
      colorScheme: const shad.ShadZincColorScheme.light().copyWith(
        background: AppColors.surface,
        foreground: AppColors.ink,
        primary: AppColors.accent,
        primaryForeground: AppColors.onAccent,
        accent: AppColors.selected,
        accentForeground: AppColors.ink,
        muted: AppColors.navigation,
        mutedForeground: AppColors.muted,
        border: AppColors.line,
        ring: AppColors.accent,
      ),
    ),
    child: DecoratedBox(
      key: const ValueKey('main-navigation-dock'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final destination in MainDestination.values)
                Expanded(
                  child: _DestinationButton(
                    destination: destination,
                    selected: destination == selected,
                    onPressed: () => onSelected(destination),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final MainDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  // Preserve MainDestination's public route/icon contract; use Lucide only in
  // this dock's presentation, from the already installed shadcn_ui package.
  IconData get icon => switch (destination) {
    MainDestination.home => shad.LucideIcons.house,
    MainDestination.library => shad.LucideIcons.layers,
    MainDestination.displays => shad.LucideIcons.monitor,
    MainDestination.more => shad.LucideIcons.ellipsis,
  };

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.feedback),
        curve: AppMotion.curve,
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          color: selected ? AppColors.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: shad.ShadButton.ghost(
          key: ValueKey('main-tab-${destination.name}'),
          // Let labels wrap with system text scaling instead of fixing height.
          height: 0,
          expands: true,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          backgroundColor: Colors.transparent,
          hoverBackgroundColor: AppColors.navigation,
          pressedBackgroundColor: AppColors.selected,
          foregroundColor: selected ? AppColors.ink : AppColors.secondaryText,
          hoverForegroundColor: AppColors.ink,
          pressedForegroundColor: AppColors.ink,
          decoration: shad.ShadDecoration(
            secondaryFocusedBorder: shad.ShadBorder.all(
              color: AppColors.accent,
              width: 2,
              radius: BorderRadius.circular(10),
            ),
          ),
          onPressed: onPressed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: selected ? AppColors.accent : null),
              const SizedBox(height: 4),
              Text(
                destination.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
