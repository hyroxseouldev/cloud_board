import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';

final _images = <String, Future<ui.Image>>{};

/// Shared asset cache. Callers must not dispose the returned image.
Future<ui.Image> loadOriginalSlideImage(String id) {
  if (id != dolpaBrickOriginalTemplateId) {
    return Future.error(
      ArgumentError.value(id, 'id', 'Unknown original slide'),
    );
  }
  return _images.putIfAbsent(id, () async {
    final bytes = await rootBundle.load(dolpaBrickOriginalAsset);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    if (image.width != originalSlideSourceSize.width ||
        image.height != originalSlideSourceSize.height) {
      image.dispose();
      throw StateError('Original slide dimensions changed');
    }
    return image;
  });
}

class OriginalSlideTextBounds {
  const OriginalSlideTextBounds({
    required this.role,
    required this.value,
    required this.rect,
    required this.fontSize,
    required this.color,
    required this.fontWeight,
  });
  final String role, value;
  final Rect rect;
  final double fontSize;
  final int color, fontWeight;

  /// Changed fields use a bundled substitute; the original source font is
  /// unknown. Unchanged fields remain the exact source bitmap glyphs.
  String get fontFamily => 'NotoSerifKR';
}

class OriginalSlideMetrics {
  const OriginalSlideMetrics({
    required this.minFontSize,
    required this.textBounds,
    required this.textRuns,
    this.warning,
  });
  final double minFontSize;
  final Rect textBounds;
  final List<OriginalSlideTextBounds> textRuns;
  final String? warning;
  bool get readable => warning == null;
}

class _Field {
  const _Field(
    this.role,
    this.value,
    this.original,
    this.bounds,
    this.fontSize,
    this.weight,
    this.color,
  );
  final String role, value, original;
  final Rect bounds;
  final double fontSize;
  final int weight, color;
  bool get changed => value.trim() != original;
}

List<_Field> _fields(WorkoutModule module) {
  final rows = originalSlideLines(module.text);
  return [
    _Field(
      'title',
      dolpaBrickOriginalTitle,
      dolpaBrickOriginalTitle,
      originalSlideTitleBounds,
      110,
      700,
      0xFFEA3458,
    ),
    _Field(
      'subtitle',
      module.designSubtitle.trim(),
      dolpaBrickOriginalSubtitle,
      originalSlideSubtitleBounds,
      65,
      400,
      0xFFFFFFFF,
    ),
    for (var i = 0; i < 4; i++)
      _Field(
        'body',
        i < rows.length ? rows[i] : '',
        dolpaBrickOriginalLines[i],
        originalSlideExerciseBounds[i],
        60,
        400,
        0xFFFFFFFF,
      ),
  ];
}

TextPainter _text(_Field field, double size) => TextPainter(
  text: TextSpan(
    text: field.value,
    style: TextStyle(
      fontFamily: 'NotoSerifKR',
      fontSize: size,
      fontWeight: FontWeight.values[field.weight ~/ 100 - 1],
      color: Color(field.color),
      height: 1.15,
    ),
  ),
  textDirection: TextDirection.ltr,
  maxLines: 1,
)..layout();

({TextPainter painter, double fontSize}) _fit(_Field field) {
  var size = field.fontSize;
  var painter = _text(field, size);
  final factor = math.min(
    1.0,
    math.min(
      field.bounds.width / math.max(1, painter.width),
      field.bounds.height / math.max(1, painter.height),
    ),
  );
  if (factor < 1) {
    size *= factor;
    painter.dispose();
    painter = _text(field, size);
  }
  return (painter: painter, fontSize: size);
}

/// Synchronous geometry, in the standard 1920×1080 output coordinate space.
OriginalSlideMetrics measureOriginalSlide(WorkoutModule module) {
  final target = originalSlideImageRect(originalSlideOutputSize);
  final scale = target.width / originalSlideSourceSize.width;
  final runs = <OriginalSlideTextBounds>[];
  var warning = originalSlideValidationError(module);
  for (final field in _fields(module)) {
    if (field.value.isEmpty) continue;
    final fitted = _fit(field);
    final rect = Rect.fromLTWH(
      target.left + field.bounds.left * scale,
      target.top + (field.bounds.center.dy - fitted.painter.height / 2) * scale,
      fitted.painter.width * scale,
      fitted.painter.height * scale,
    );
    final fontSize = (field.changed ? fitted.fontSize : field.fontSize) * scale;
    if (field.changed && fontSize < 36) {
      warning ??= '원본의 글자 영역에 맞게 제목이나 운동 문구를 줄여 주세요.';
    }
    runs.add(
      OriginalSlideTextBounds(
        role: field.role,
        value: field.value,
        rect: rect,
        fontSize: fontSize,
        color: field.color,
        fontWeight: field.weight,
      ),
    );
    fitted.painter.dispose();
  }
  return OriginalSlideMetrics(
    minFontSize: runs.isEmpty
        ? 0
        : runs.map((r) => r.fontSize).reduce(math.min),
    textBounds: runs.isEmpty
        ? Rect.zero
        : runs.map((r) => r.rect).reduce((a, b) => a.expandToInclude(b)),
    textRuns: List.unmodifiable(runs),
    warning: warning,
  );
}

/// The baseline draws only the original image. Editing changes just the named
/// text slots; all original calligraphy remains source pixels. Colors/layout
/// are fixed by this recipe, independent of generic design style controls.
void paintOriginalSlide(
  Canvas canvas,
  Size size,
  WorkoutModule module,
  ui.Image image,
) {
  // Incomplete editor drafts may still preview. The validation/metrics warning
  // blocks applying or exporting overflow, while the source module keeps all
  // entered content. Only this fixed recipe's four slots are drawn here.
  if (!isOriginalSlideTemplate(module)) {
    throw ArgumentError('Unknown original slide template');
  }
  final target = originalSlideImageRect(size);
  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
  canvas.save();
  canvas.translate(target.left, target.top);
  final scale = target.width / originalSlideSourceSize.width;
  canvas.scale(scale);
  canvas.drawImage(
    image,
    Offset.zero,
    Paint()..filterQuality = FilterQuality.medium,
  );
  for (final field in _fields(module)) {
    if (!field.changed) continue;
    final clear = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    canvas.drawRect(field.bounds, clear);
    if (field.value.isEmpty) continue;
    final fitted = _fit(field);
    canvas.save();
    canvas.clipRect(field.bounds);
    fitted.painter.paint(
      canvas,
      Offset(
        field.bounds.left,
        field.bounds.center.dy - fitted.painter.height / 2,
      ),
    );
    canvas.restore();
    fitted.painter.dispose();
  }
  canvas.restore();
}
