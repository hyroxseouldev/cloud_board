import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('main-navigation-dock'),
    color: Colors.white,
    elevation: 1,
    shadowColor: AppColors.accent.withValues(alpha: .14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(32),
      side: const BorderSide(color: AppColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final destination in MainDestination.values)
              Expanded(
                child: Semantics(
                  selected: destination == selected,
                  button: true,
                  label: destination.label,
                  excludeSemantics: true,
                  onTap: () => onSelected(destination),
                  child: InkWell(
                    key: ValueKey('main-tab-${destination.name}'),
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => onSelected(destination),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 60),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: destination == selected
                                  ? AppColors.selected
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              destination == selected
                                  ? destination.selectedIcon
                                  : destination.icon,
                              size: 24,
                              color: destination == selected
                                  ? AppColors.accent
                                  : AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            destination.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: destination == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: destination == selected
                                  ? AppColors.ink
                                  : AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
