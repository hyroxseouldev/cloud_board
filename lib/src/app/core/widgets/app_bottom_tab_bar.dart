import 'package:flutter/material.dart';

class AppBottomTab {
  const AppBottomTab({required this.label, required this.icon, this.flex = 1});
  final String label;
  final IconData icon;
  final int flex;
}

class AppBottomTabBar extends StatelessWidget {
  const AppBottomTabBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.items,
    this.stackedBelowWidth = 0,
    this.indicatorKey,
  });

  final List<AppBottomTab> items;
  final double stackedBelowWidth;
  final Key? indicatorKey;

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < stackedBelowWidth ||
                  constraints.maxWidth < 600 &&
                      MediaQuery.textScalerOf(context).scale(12) >
                          (constraints.maxWidth < 350 ? 12 : 14);
              final totalFlex = items.fold(0, (sum, item) => sum + item.flex);
              final leadingFlex = items
                  .take(selected)
                  .fold(0, (sum, item) => sum + item.flex);
              final slot = (constraints.maxWidth - 16) / totalFlex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      left: leadingFlex * slot + 2,
                      width: items[selected].flex * slot - 4,
                      top: 6,
                      bottom: 6,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: indicatorKey,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final (index, item) in items.indexed)
                          Expanded(
                            flex: item.flex,
                            child: Semantics(
                              selected: selected == index,
                              button: true,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => onSelected(index),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 6,
                                  ),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 36,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 6,
                                    ),
                                    child: Flex(
                                      direction: stacked
                                          ? Axis.vertical
                                          : Axis.horizontal,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 18,
                                          color: selected == index
                                              ? colors.primary
                                              : colors.onSurfaceVariant,
                                        ),
                                        SizedBox(
                                          width: stacked ? 0 : 4,
                                          height: stacked ? 4 : 0,
                                        ),
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            fontSize: constraints.maxWidth < 350
                                                ? 11
                                                : 12,
                                            fontWeight: selected == index
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: selected == index
                                                ? colors.primary
                                                : colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
