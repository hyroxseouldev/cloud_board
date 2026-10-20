import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/slide_studio_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/slide_studio_page.dart';

class AiBetaBadge extends StatelessWidget {
  const AiBetaBadge({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 4 : 7,
      vertical: compact ? 1 : 3,
    ),
    decoration: BoxDecoration(
      color: AppColors.selected,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      'beta',
      style: TextStyle(
        fontSize: compact ? 9 : 11,
        fontWeight: FontWeight.w600,
        letterSpacing: .4,
        color: AppColors.accent,
      ),
    ),
  );
}

Future<List<WorkoutModule>?> showAiSlidesPage(BuildContext context) {
  final parent = GoRouterState.of(context).uri.path
      .replaceFirst(RegExp(r'/$'), '');
  return context.push<List<WorkoutModule>>('$parent/images/create');
}

/// Each creation route has an account/center-scoped, isolated studio lifetime.
class AiSlidesPage extends HookConsumerWidget {
  const AiSlidesPage({super.key, this.guard});
  final ExitGuard? guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(centerSlideCatalogScopeProvider);
    final owner = ref.watch(aiSlidesOwnerIdProvider);
    final exitGuard = useMemoized(() => guard ?? ExitGuard(), [guard]);
    return ProviderScope(
      key: ValueKey((owner, scope)),
      overrides: [
        slideStudioControllerProvider.overrideWith(SlideStudioController.new),
        aiSlideDesignControllerProvider.overrideWith(
          AiSlideDesignController.fresh,
        ),
      ],
      child: SlideStudioPage(guard: exitGuard),
    );
  }
}
