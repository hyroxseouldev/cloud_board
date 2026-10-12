import 'package:flutter/widgets.dart';

/// The same v5 master artwork used by launcher icons and native launch screens.
class SoftRhythmMark extends StatelessWidget {
  const SoftRhythmMark({super.key, this.size = 32, this.semanticLabel});

  static const asset = 'assets/branding/soft_rhythm_mark.png';
  final double size;
  final String? semanticLabel;

  static ImageProvider imageProvider(BuildContext context, double size) =>
      ResizeImage.resizeIfNeeded(
        (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
        null,
        const AssetImage(asset),
      );

  @override
  Widget build(BuildContext context) => Image(
    image: imageProvider(context, size),
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    semanticLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
    gaplessPlayback: true,
  );
}
