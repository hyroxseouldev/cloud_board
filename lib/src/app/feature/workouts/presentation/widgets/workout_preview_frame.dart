import 'package:flutter/material.dart';

/// Editor/settings/thumbnail bounds only; playback owns its own letterboxing.
/// No backing paint, border, crop, or extra inset is added around the image.
class WorkoutPreviewFrame extends StatelessWidget {
  const WorkoutPreviewFrame({
    super.key,
    required this.child,
    this.borderRadius = 12,
  });

  final Widget child;
  final double borderRadius;

  // Use the same canvas-first cache key at every preview radius, retaining
  // HTML compatibility for remote images whose server does not allow CORS.
  static const webImageStrategy = WebHtmlElementStrategy.fallback;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: borderRadius == 0 ? Clip.hardEdge : Clip.antiAlias,
      child: SizedBox.expand(child: child),
    ),
  );
}
