import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shadcn;

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_motion.dart';

/// Installs only page-local component infrastructure; the app's Material theme,
/// Navigator, account providers and route lifecycle remain outside this scope.
class PreparationShadcnScope extends StatelessWidget {
  const PreparationShadcnScope({super.key, required this.child});
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

class PreparationDeviceTile extends StatelessWidget {
  const PreparationDeviceTile({
    super.key,
    required this.name,
    required this.status,
    required this.selected,
    required this.onChanged,
  });
  final String name;
  final String status;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => onChanged(!selected),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: shadcn.ShadCheckbox(
        value: selected,
        onChanged: onChanged,
        size: 18,
        label: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        sublabel: Text(
          status,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ),
    ),
  );
}

/// Same observed-stage timing as the shared Material status, with shadcn UI.
class PreparationShadcnStage extends HookWidget {
  const PreparationShadcnStage({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final slow = useState(false);
    useEffect(() {
      slow.value = false;
      final timer = Timer(const Duration(seconds: 5), () => slow.value = true);
      return timer.cancel;
    }, [label]);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (AppMotion.reduced(context))
              const Icon(
                shadcn.LucideIcons.hourglass,
                size: 20,
                color: AppColors.accent,
              )
            else
              const SizedBox(
                width: 20,
                height: 20,
                child: Center(child: shadcn.ShadProgress(minHeight: 3)),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (slow.value)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '$label · 5초 이상 기다리고 있어요.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
