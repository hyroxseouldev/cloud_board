import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';

/// Lists only read pre-generated small PNGs; legacy catalogs get a cheap tile.
class CenterSlideThumbnail extends ConsumerWidget {
  const CenterSlideThumbnail({super.key, required this.draft});
  final AiSlideDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = draft.centerRecipe!;
    final thumbnail = recipe.thumbnail == null
        ? null
        : ref.watch(centerSlideThumbnailProvider(recipe));
    Widget placeholder(String label) => Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: thumbnail == null
            ? placeholder('${draft.title}\n선택하여 디자인 확인')
            : thumbnail.when(
                skipLoadingOnReload: false,
                data: (image) => image == null
                    ? placeholder('선택하여 디자인 확인')
                    : RawImage(image: image, fit: BoxFit.contain),
                // Static skeleton respects reduced motion without extra timers.
                loading: () => const Center(
                  child: SizedBox(
                    width: 120,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x22777777),
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
                error: (_, _) => Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.invalidate(centerSlideThumbnailProvider(recipe)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('미리보기 다시 시도'),
                  ),
                ),
              ),
      ),
    );
  }
}
