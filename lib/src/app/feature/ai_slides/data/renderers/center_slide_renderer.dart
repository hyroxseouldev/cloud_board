import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';

const centerSlideOutputWidth = 1920;
const centerSlideOutputHeight = 1080;
const centerSlideMinimumOutputFontSize = 24.0;

/// Creation-only raster export. The caller owns authenticated asset loading;
/// this function never fetches data or changes a workout/display renderer.
Future<Uint8List> renderCenterSlide(
  CenterSlideRecipe recipe,
  AiSlideDraft draft, {
  Uint8List? backgroundBytes,
}) async {
  final recipeError = validateCenterSlideRecipe(recipe);
  if (recipeError != null) throw FormatException(recipeError);
  _validateContent(recipe, draft);
  final hasBackground = recipe.backgroundPath != null;
  if (hasBackground != (backgroundBytes != null)) {
    throw const FormatException('센터 템플릿의 원본 이미지를 다시 불러와 주세요.');
  }

  ui.Image? background;
  final fields = <_PreparedField>[];
  final scale = math.min(
    centerSlideOutputWidth / recipe.width,
    centerSlideOutputHeight / recipe.height,
  );
  try {
    if (backgroundBytes != null) {
      background = await _decodeBackground(recipe, backgroundBytes);
    }
    for (final field in recipe.fields) {
      final value = _fieldValue(field, draft);
      // Preserve source pixels, including the original typeface/texture, until
      // this exact field changes. Empty original slots are meaningful too.
      if (hasBackground &&
          field.originalText != null &&
          value == field.originalText) {
        continue;
      }
      fields.add(_prepareField(field, recipe, value, scale));
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(
        0,
        0,
        centerSlideOutputWidth * 1.0,
        centerSlideOutputHeight * 1.0,
      ),
      Paint()..color = Color(recipe.backgroundColor),
    );
    canvas.save();
    canvas.translate(
      (centerSlideOutputWidth - recipe.width * scale) / 2,
      (centerSlideOutputHeight - recipe.height * scale) / 2,
    );
    canvas.scale(scale);
    if (background != null) {
      canvas.drawImageRect(
        background,
        Rect.fromLTWH(
          0,
          0,
          background.width.toDouble(),
          background.height.toDouble(),
        ),
        Rect.fromLTWH(0, 0, recipe.width.toDouble(), recipe.height.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    for (final field in fields) {
      if (field.clear) {
        canvas.drawRect(
          field.bounds,
          Paint()
            ..color = Color(field.clearColor)
            ..blendMode = BlendMode.src
            ..isAntiAlias = false,
        );
      }
      if (field.painter != null) {
        // Fitting is validated before drawing; the clip also contains italic
        // glyph overhang and antialiasing inside the declared editable region.
        canvas.save();
        canvas.clipRect(field.bounds, doAntiAlias: false);
        field.painter!.paint(canvas, field.offset);
        canvas.restore();
      }
    }
    canvas.restore();
    final picture = recorder.endRecording();
    try {
      final output = await picture.toImage(
        centerSlideOutputWidth,
        centerSlideOutputHeight,
      );
      try {
        final png = await output.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) {
          throw const FormatException('센터 슬라이드 이미지를 만들지 못했어요.');
        }
        return Uint8List.fromList(
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        );
      } finally {
        output.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    for (final field in fields) {
      field.painter?.dispose();
    }
    background?.dispose();
  }
}

Future<ui.Image> _decodeBackground(
  CenterSlideRecipe recipe,
  Uint8List bytes,
) async {
  const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 24 ||
      bytes.length > centerSlideMaximumBackgroundBytes ||
      !List.generate(
        8,
        (index) => bytes[index] == pngSignature[index],
      ).every((same) => same) ||
      bytes[12] != 73 ||
      bytes[13] != 72 ||
      bytes[14] != 68 ||
      bytes[15] != 82) {
    throw const FormatException('센터 템플릿 원본은 10MB 이내의 PNG여야 해요.');
  }
  final header = ByteData.sublistView(bytes);
  if (header.getUint32(16) != recipe.width ||
      header.getUint32(20) != recipe.height) {
    throw const FormatException('센터 템플릿 원본 이미지 크기가 변경되었어요.');
  }
  if (sha256.convert(bytes).toString() != recipe.backgroundSha256) {
    throw const FormatException('센터 템플릿 원본 이미지가 변경되었어요. 다시 불러와 주세요.');
  }
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    if (codec.frameCount != 1) {
      throw const FormatException('움직이는 PNG는 센터 템플릿으로 사용할 수 없어요.');
    }
    final image = (await codec.getNextFrame()).image;
    if (image.width != recipe.width || image.height != recipe.height) {
      image.dispose();
      throw const FormatException('센터 템플릿 원본 이미지 크기가 변경되었어요.');
    }
    return image;
  } finally {
    codec.dispose();
  }
}

String _fieldValue(CenterSlideField field, AiSlideDraft draft) =>
    switch (field.binding) {
      'title' => draft.title,
      'subtitle' => draft.designSubtitle,
      'header' => draft.designHeaderLabel,
      'line' =>
        field.lineIndex! < draft.lines.length
            ? draft.lines[field.lineIndex!]
            : '',
      _ => throw const FormatException('센터 템플릿의 편집 항목을 확인해 주세요.'),
    };

void _validateContent(CenterSlideRecipe recipe, AiSlideDraft draft) {
  final controls = RegExp(r'[\x00-\x1F\x7F]');
  void validateText(String value, int maximum) {
    if (value.runes.length > maximum || controls.hasMatch(value)) {
      throw const FormatException('문구는 길이 제한 안에서 한 줄로 입력해 주세요.');
    }
  }

  if (draft.title.trim().isEmpty) {
    throw const FormatException('슬라이드 제목을 입력해 주세요.');
  }
  validateText(draft.title, 60);
  validateText(draft.designSubtitle, 120);
  validateText(draft.designHeaderLabel, 120);
  if (draft.lines.length > centerSlideMaximumLines) {
    throw const FormatException('센터 템플릿의 운동 문구는 24줄 이내로 입력해 주세요.');
  }
  final lineIndices = recipe.fields
      .where((field) => field.binding == 'line')
      .map((field) => field.lineIndex!)
      .toSet();
  for (var index = 0; index < draft.lines.length; index++) {
    final value = draft.lines[index];
    validateText(value, 120);
    if (value.isNotEmpty && !lineIndices.contains(index)) {
      throw const FormatException('템플릿에 표시할 수 없는 운동 문구가 있어요. 줄 수를 확인해 주세요.');
    }
  }
}

class _PreparedField {
  const _PreparedField({
    required this.bounds,
    required this.clear,
    required this.clearColor,
    this.painter,
    this.offset = Offset.zero,
  });
  final Rect bounds;
  final bool clear;
  final int clearColor;
  final TextPainter? painter;
  final Offset offset;
}

_PreparedField _prepareField(
  CenterSlideField field,
  CenterSlideRecipe recipe,
  String value,
  double outputScale,
) {
  final bounds = Rect.fromLTWH(
    field.x * recipe.width,
    field.y * recipe.height,
    field.width * recipe.width,
    field.height * recipe.height,
  );
  final clear = field.originalText != null || field.clearColor != null;
  final clearColor = field.clearColor ?? recipe.backgroundColor;
  if (value.isEmpty) {
    return _PreparedField(bounds: bounds, clear: clear, clearColor: clearColor);
  }

  TextPainter text(double size) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: field.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.values[field.fontWeight ~/ 100 - 1],
        fontStyle: field.italic ? FontStyle.italic : FontStyle.normal,
        color: Color(field.color),
        height: 1.15,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  var size = field.fontSize;
  var painter = text(size);
  // Reserve a small inset for glyph overhang; this is inside the slot, not an
  // expansion that could erase adjacent original artwork.
  double inset(double fontSize) => fontSize * (field.italic ? .16 : .04);
  final fit = math.min(
    1.0,
    math.min(
      bounds.width / math.max(1, painter.width + inset(size) * 2),
      bounds.height / math.max(1, painter.height),
    ),
  );
  if (fit < 1) {
    size *= fit;
    painter.dispose();
    painter = text(size);
  }
  final padding = inset(size);
  if (size * outputScale < centerSlideMinimumOutputFontSize ||
      painter.width + padding * 2 > bounds.width + .01 ||
      painter.height > bounds.height + .01 ||
      painter.didExceedMaxLines) {
    painter.dispose();
    throw const FormatException('글씨가 너무 작아져요. 제목이나 운동 문구를 줄여 주세요.');
  }
  final left = switch (field.align) {
    'center' => bounds.center.dx - painter.width / 2,
    'right' => bounds.right - painter.width - padding,
    _ => bounds.left + padding,
  };
  return _PreparedField(
    bounds: bounds,
    clear: clear,
    clearColor: clearColor,
    painter: painter,
    offset: Offset(left, bounds.center.dy - painter.height / 2),
  );
}
