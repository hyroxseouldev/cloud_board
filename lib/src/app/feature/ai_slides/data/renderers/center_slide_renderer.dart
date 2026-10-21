import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_flow_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_flow.dart';
import 'package:flutter/painting.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';

const centerSlideOutputWidth = 1920;
const centerSlideOutputHeight = 1080;
const centerSlideMinimumOutputFontSize = 24.0;

/// Measured once for a draft; preview and final PNG paint this exact layout.
/// No image encoding/decoding or network work happens in this calculation.
class CenterSlideLayout {
  CenterSlideLayout._(this.recipe, this._fields, this.flow);
  final CenterSlideRecipe recipe;
  final List<_PreparedField> _fields;
  final CenterSlideFlowLayout? flow;

  void paint(Canvas canvas, Size size, {ui.Image? background}) {
    final scale = math.min(
      size.width / recipe.width,
      size.height / recipe.height,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color(recipe.backgroundColor),
    );
    canvas.save();
    canvas.translate(
      (size.width - recipe.width * scale) / 2,
      (size.height - recipe.height * scale) / 2,
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
    for (final field in _fields) {
      if (field.clear) {
        canvas.drawRect(
          field.bounds,
          Paint()
            ..color = Color(field.clearColor)
            ..blendMode = BlendMode.src
            ..isAntiAlias = false,
        );
      }
      field.painter?.paint(canvas, field.offset);
    }
    flow?.paint(canvas);
    canvas.restore();
  }

  void dispose() {
    for (final field in _fields) {
      field.painter?.dispose();
    }
    flow?.dispose();
  }
}

CenterSlideLayout prepareCenterSlideLayout(
  CenterSlideRecipe recipe,
  AiSlideDraft draft,
) {
  final error = validateCenterSlideRecipe(recipe);
  if (error != null) throw FormatException(error);
  _validateContent(recipe, draft);
  final fields = <_PreparedField>[];
  CenterSlideFlowLayout? flow;
  final scale = math.min(
    centerSlideOutputWidth / recipe.width,
    centerSlideOutputHeight / recipe.height,
  );
  try {
    for (final field in recipe.fields) {
      final value = _fieldValue(field, draft);
      if (recipe.backgroundPath != null &&
          field.originalText != null &&
          value == field.originalText) {
        continue;
      }
      fields.add(_prepareField(field, recipe, value, scale));
    }
    if (recipe.body != null) {
      flow = layoutCenterSlideFlow(
        recipe: recipe,
        lines: draft.lines,
        outputScale: scale,
        fixedColumns: draft.centerColumns,
        fontSize: draft.centerFontSize,
      );
    }
    return CenterSlideLayout._(recipe, fields, flow);
  } catch (_) {
    for (final field in fields) {
      field.painter?.dispose();
    }
    flow?.dispose();
    rethrow;
  }
}

/// Explicit final export only. Preview never calls this PNG path.
Future<Uint8List> renderCenterSlide(
  CenterSlideRecipe recipe,
  AiSlideDraft draft, {
  Uint8List? backgroundBytes,
}) async {
  if ((recipe.backgroundPath != null) != (backgroundBytes != null)) {
    throw const FormatException('센터 템플릿의 원본 이미지를 다시 불러와 주세요.');
  }
  final layout = prepareCenterSlideLayout(recipe, draft);
  ui.Image? background;
  try {
    if (backgroundBytes != null) {
      background = await decodeCenterSlideBackground(recipe, backgroundBytes);
    }
    final recorder = ui.PictureRecorder();
    layout.paint(
      Canvas(recorder),
      const Size(1920, 1080),
      background: background,
    );
    final picture = recorder.endRecording();
    try {
      final output = await picture.toImage(
        centerSlideOutputWidth,
        centerSlideOutputHeight,
      );
      try {
        final png = await output.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) throw const FormatException('센터 슬라이드 이미지를 만들지 못했어요.');
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
    layout.dispose();
    background?.dispose();
  }
}

Future<ui.Image> decodeCenterSlideBackground(
  CenterSlideRecipe recipe,
  Uint8List bytes, {
  int? targetWidth,
}) async {
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
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: targetWidth,
    allowUpscaling: false,
  );
  try {
    if (codec.frameCount != 1) {
      throw const FormatException('움직이는 PNG는 센터 템플릿으로 사용할 수 없어요.');
    }
    final image = (await codec.getNextFrame()).image;
    if (targetWidth == null &&
        (image.width != recipe.width || image.height != recipe.height)) {
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
  if (recipe.body != null) {
    final error = centerSlideFlowContentError(draft.lines);
    if (error != null) throw FormatException(error);
    return;
  }
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

  TextPainter text(double size) =>
      TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: field.fontFamily,
            fontSize: size,
            fontWeight: FontWeight.values[field.fontWeight ~/ 100 - 1],
            fontStyle: field.italic ? FontStyle.italic : FontStyle.normal,
            color: Color(field.color),
            // Fixed recipe slots follow the original artwork's glyph size.
            // Extra paragraph leading can exceed the slot even for one short
            // line (e.g. 52.9px type in a 55.5px SINGLE field). Keep the font
            // size and slot geometry; actual wrapped overflow still fails.
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(
        maxWidth: math.max(1, bounds.width - size * (field.italic ? .32 : .08)),
      );

  final size = field.fontSize;
  final painter = text(size);
  double inset(double fontSize) => fontSize * (field.italic ? .16 : .04);
  final padding = inset(size);
  final minimum = recipe.schemaVersion == 2
      ? centerSlideFlowMinimumOutputFontSize
      : centerSlideMinimumOutputFontSize;
  if (size * outputScale < minimum ||
      painter.width + padding * 2 > bounds.width + .01 ||
      painter.height > bounds.height + .01 ||
      painter.didExceedMaxLines) {
    painter.dispose();
    throw const FormatException(
      '선택한 글자 크기에 문구가 넘쳐요. 제목이나 운동 문구를 줄이거나 슬라이드를 나눠 주세요.',
    );
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
