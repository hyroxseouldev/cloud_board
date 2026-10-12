import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Keeps gallery geometry/selectability while decoding and painting artwork
/// only for cards intersecting the nearest scroll viewport. Leaving it unmounts
/// the preview, releasing that card's image handle.
class VisibleSlidePreview extends HookWidget {
  const VisibleSlidePreview({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final visible = useState(false);
    final scrollable = Scrollable.maybeOf(context);
    useEffect(() {
      var mounted = true;
      var scheduled = false;
      void check() {
        if (scheduled) return;
        scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scheduled = false;
          if (!mounted) return;
          final box = context.findRenderObject();
          if (box is! RenderBox || !box.hasSize || !box.attached) return;
          final viewport = RenderAbstractViewport.maybeOf(box);
          final isVisible =
              viewport == null ||
              MatrixUtils.transformRect(
                box.getTransformTo(viewport),
                Offset.zero & box.size,
              ).overlaps(viewport.paintBounds);
          if (visible.value != isVisible) visible.value = isVisible;
        });
      }

      scrollable?.position.addListener(check);
      check();
      return () {
        mounted = false;
        scrollable?.position.removeListener(check);
      };
    });
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: visible.value
          ? builder(context)
          : const ColoredBox(color: Color(0xFF202020)),
    );
  }
}
