import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Private pixels stay in this widget lifetime, never Flutter's global image
/// cache or an unauthenticated URL. Parent account/center scopes dispose it.
class TemplateJobImage extends HookWidget {
  const TemplateJobImage({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) {
    final image = useState<ui.Image?>(null);
    final failed = useState(false);
    useEffect(() {
      var active = true;
      ui.Image? owned;
      image.value = null;
      failed.value = false;
      () async {
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          try {
            if (codec.frameCount != 1) {
              throw const FormatException('PNG required');
            }
            final decoded = (await codec.getNextFrame()).image;
            if (!active) {
              decoded.dispose();
              return;
            }
            owned = decoded;
            image.value = decoded;
          } finally {
            codec.dispose();
          }
        } catch (_) {
          if (active) failed.value = true;
        }
      }();
      return () {
        active = false;
        owned?.dispose();
      };
    }, [bytes]);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: failed.value
          ? const Center(child: Text('이미지를 표시하지 못했어요. 다시 열어 주세요.'))
          : image.value == null
          ? const Center(child: Text('이미지 불러오는 중…'))
          : RawImage(image: image.value, fit: BoxFit.contain),
    );
  }
}
