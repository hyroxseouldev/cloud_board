import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';

const rasterCanvasSize = Size(1920, 1080);
const rasterTimerBlank = Rect.fromLTWH(1260, 0, 660, 1080);
Color rasterColor(String value) =>
    Color(int.parse(value.substring(1), radix: 16) | 0xff000000);

/// The generated artwork is separate from exact user text and official pixels.
/// Preview and final export share every measured position; neither clips text.
class AiRasterLayout {
  AiRasterLayout(this.draft, this.brand) {
    final error = rasterDraftError(draft);
    if (error != null) throw FormatException(error);
    try {
      _text(
        draft.title,
        const Rect.fromLTWH(60, 230, 1140, 90),
        64,
        FontWeight.w700,
        rasterColor(brand.textColor),
      );
      const body = Rect.fromLTWH(60, 340, 1140, 650);
      const gutter = 28.0;
      final width =
          (body.width - gutter * (draft.groups.length - 1)) /
          draft.groups.length;
      for (final (i, group) in draft.groups.indexed) {
        final x = body.left + i * (width + gutter);
        _text(
          group.heading,
          Rect.fromLTWH(x, body.top, width, 66),
          44,
          FontWeight.w700,
          rasterColor(brand.accentColor),
        );
        _text(
          group.lines.join('\n'),
          Rect.fromLTWH(x, body.top + 82, width, body.height - 82),
          draft.bodyFontSize,
          FontWeight.w600,
          rasterColor(brand.textColor),
        );
      }
    } catch (_) {
      dispose();
      rethrow;
    }
  }
  final AiRasterDraft draft;
  final AiRasterBrand brand;
  final _runs = <({TextPainter painter, Offset offset})>[];
  void _text(
    String value,
    Rect rect,
    double size,
    FontWeight weight,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: size,
          height: 1.2,
          fontWeight: weight,
          color: color,
          shadows: [
            Shadow(
              color: rasterColor(brand.backgroundColor).withValues(alpha: .8),
              blurRadius: 3,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);
    if (painter.height > rect.height ||
        painter.computeLineMetrics().any(
          (line) => line.width > rect.width + .01,
        )) {
      painter.dispose();
      throw const FormatException(
        '선택한 글자 크기에 내용이 넘쳐요. 그룹을 나누거나 수업 내용을 여러 슬라이드로 분리해 주세요.',
      );
    }
    _runs.add((painter: painter, offset: rect.topLeft));
  }

  void paint(Canvas canvas, Size size, ui.Image artwork, ui.Image logo) {
    canvas.save();
    canvas.scale(size.width / 1920, size.height / 1080);
    canvas.drawImageRect(
      artwork,
      Rect.fromLTWH(0, 0, artwork.width.toDouble(), artwork.height.toDouble()),
      Offset.zero & rasterCanvasSize,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final clear = Paint()..color = rasterColor(brand.backgroundColor);
    // Enforce only the timer exclusion and exact logo slot. Preserve generated
    // artwork behind the content; sample review must assess incidental lettering
    // and contrast instead of hiding most of the artwork with an opaque board.
    for (final rect in [
      rasterTimerBlank,
      const Rect.fromLTWH(40, 20, 460, 190),
    ]) {
      canvas.drawRect(rect, clear);
    }
    final crop = brand.logo.sourceRect;
    final scaleX = logo.width / brand.logo.width,
        scaleY = logo.height / brand.logo.height;
    final source = Rect.fromLTWH(
      crop[0] * scaleX,
      crop[1] * scaleY,
      crop[2] * scaleX,
      crop[3] * scaleY,
    );
    canvas.drawImageRect(
      logo,
      source,
      Rect.fromLTWH(60, 30, 390, 390 * crop[3] / crop[2]),
      Paint()..filterQuality = FilterQuality.high,
    );
    for (final run in _runs) {
      run.painter.paint(canvas, run.offset);
    }
    canvas.restore();
  }

  void dispose() {
    for (final run in _runs) {
      run.painter.dispose();
    }
    _runs.clear();
  }
}

String? rasterLayoutError(AiRasterDraft draft, AiRasterBrand brand) {
  try {
    AiRasterLayout(draft, brand).dispose();
    return null;
  } on FormatException catch (error) {
    return error.message;
  }
}

Future<ui.Image> decodeRasterImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    if (codec.frameCount != 1) {
      throw const FormatException('움직이는 이미지는 지원하지 않아요.');
    }
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> composeRasterSlide(
  AiRasterDraft draft,
  AiRasterBrand brand,
  Uint8List artworkBytes,
  Uint8List logoBytes,
) async {
  final layout = AiRasterLayout(draft, brand);
  ui.Image? artwork, logo;
  try {
    artwork = await decodeRasterImage(artworkBytes);
    logo = await decodeRasterImage(logoBytes);
    final recorder = ui.PictureRecorder();
    layout.paint(Canvas(recorder), rasterCanvasSize, artwork, logo);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(1920, 1080);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw const FormatException('슬라이드를 만들지 못했어요.');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    artwork?.dispose();
    logo?.dispose();
    layout.dispose();
  }
}
