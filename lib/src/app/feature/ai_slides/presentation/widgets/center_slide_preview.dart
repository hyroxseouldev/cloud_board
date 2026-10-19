import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';

/// Creation-only preview. The display/player never reads private templates.
class CenterSlidePreview extends ConsumerWidget {
  const CenterSlidePreview({
    super.key,
    required this.draft,
    this.compact = false,
  });
  final AiSlideDraft draft;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(centerSlidePreviewProvider(draft));
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        child: preview.when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: false,
          data: (bytes) =>
              Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: false),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error is AiSlidesFailure
                        ? error.message
                        : '미리보기를 불러오지 못했어요.',
                    textAlign: TextAlign.center,
                    maxLines: compact ? 2 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 11 : 14),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(centerSlidePreviewProvider(draft)),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
