import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';

/// Creation-only preview. The display/player never reads private templates.
class CenterSlidePreview extends HookConsumerWidget {
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
    final scope = ref.watch(centerSlideCatalogScopeProvider);
    final previous = useMemoized(() => <Uint8List>[], [
      scope,
      draft.centerRecipe,
    ]);
    if (preview.hasError) previous.clear();
    if (preview.hasValue && !preview.isLoading && !preview.hasError) {
      previous
        ..clear()
        ..add(preview.requireValue);
    }
    Widget loading() {
      if (draft.centerRecipe?.body == null || previous.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(previous.single, fit: BoxFit.contain),
          const Align(
            alignment: Alignment.bottomCenter,
            child: LinearProgressIndicator(minHeight: 3),
          ),
        ],
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        child: preview.when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: false,
          data: (bytes) =>
              Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: false),
          loading: loading,
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
