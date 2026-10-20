import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';

/// Direct creation canvas. Text edits never enter the final PNG exporter.
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
    final background = ref.watch(
      centerSlideBackgroundProvider(draft.centerRecipe!),
    );
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Color(draft.centerRecipe!.backgroundColor),
        child: preview.when(
          skipLoadingOnReload: false,
          data: (layout) => CustomPaint(
            key: const ValueKey('center-slide-direct-canvas'),
            painter: _CenterSlidePainter(layout, background.value),
            size: Size.infinite,
          ),
          loading: () => const Center(child: Text('미리보기 준비 중…')),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error is AiSlidesFailure
                        ? error.message
                        : error is FormatException
                        ? error.message
                        : '미리보기를 불러오지 못했어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: compact ? 11 : 14),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(
                        centerSlideBackgroundProvider(draft.centerRecipe!),
                      );
                      ref.invalidate(centerSlidePreviewProvider(draft));
                    },
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

class _CenterSlidePainter extends CustomPainter {
  const _CenterSlidePainter(this.layout, this.background);
  final CenterSlideLayout layout;
  final ui.Image? background;
  @override
  void paint(Canvas canvas, Size size) =>
      layout.paint(canvas, size, background: background);
  @override
  bool shouldRepaint(_CenterSlidePainter old) =>
      layout != old.layout || background != old.background;
}
