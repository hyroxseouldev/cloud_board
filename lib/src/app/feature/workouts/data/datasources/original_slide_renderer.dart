import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';

/// Cache-owned handles are separate from caller-owned clones. Eviction can
/// dispose an idle cache handle without invalidating a painter or export.
class OriginalSlideImageCache {
  OriginalSlideImageCache({required this.maximumBytes});
  final int maximumBytes;
  final _entries = <String, _OriginalImageEntry>{};
  int get retainedBytes => _entries.values.fold(0, (sum, e) => sum + e.bytes);
  int get length => _entries.length;

  Future<ui.Image> load(String key, Future<ui.Image> Function() decode) async {
    final entry = _entries.remove(key) ?? _OriginalImageEntry();
    _entries[key] = entry;
    entry.readers++;
    try {
      entry.pending ??= decode().then((image) {
        entry.image = image;
        return image;
      });
      final image = await entry.pending!;
      // The reader count pins the cache handle until this clone is created.
      return image.clone();
    } catch (_) {
      if (identical(_entries[key], entry)) _entries.remove(key);
      entry.evicted = true;
      rethrow;
    } finally {
      entry.readers--;
      while (retainedBytes > maximumBytes && _entries.isNotEmpty) {
        final oldest = _entries.remove(_entries.keys.first)!;
        oldest.evicted = true;
        oldest.disposeIfUnused();
      }
      entry.disposeIfUnused();
    }
  }

  void clear() {
    for (final entry in _entries.values) {
      entry.evicted = true;
      entry.disposeIfUnused();
    }
    _entries.clear();
  }
}

class _OriginalImageEntry {
  Future<ui.Image>? pending;
  ui.Image? image;
  int readers = 0;
  bool evicted = false;
  int get bytes => image == null ? 0 : image!.width * image!.height * 4;
  void disposeIfUnused() {
    if (evicted && readers == 0) {
      image?.dispose();
      image = null;
    }
  }
}

/// LRU budgets exclude active caller clones, which are released by their owners.
/// Previews use at most 16 MiB; full-resolution export sources use 64 MiB.
final originalSlidePreviewCache = OriginalSlideImageCache(
  maximumBytes: 16 * 1024 * 1024,
);
final originalSlideExportCache = OriginalSlideImageCache(
  maximumBytes: 64 * 1024 * 1024,
);

class _OriginalImageMemoryObserver extends WidgetsBindingObserver {
  @override
  void didHaveMemoryPressure() {
    originalSlidePreviewCache.clear();
    originalSlideExportCache.clear();
  }
}

bool _observesMemoryPressure = false;
final _originalMemoryObserver = _OriginalImageMemoryObserver();

/// Returns a caller-owned handle. Always dispose it after painting/exporting.
/// [targetWidth] is in physical pixels; omission requests the exact original.
Future<ui.Image> loadOriginalSlideImage(String id, {int? targetWidth}) {
  if (!_observesMemoryPressure) {
    WidgetsBinding.instance.addObserver(_originalMemoryObserver);
    _observesMemoryPressure = true;
  }
  final template = originalSlideTemplate(id);
  if (template == null) {
    return Future.error(
      ArgumentError.value(id, 'id', 'Unknown original slide'),
    );
  }
  final width = targetWidth == null
      ? null
      : (((targetWidth.clamp(1, 3840) + 63) ~/ 64) * 64).clamp(
          1,
          template.sourceSize.width.toInt(),
        );
  final cache = width == null
      ? originalSlideExportCache
      : originalSlidePreviewCache;
  return cache.load('$id:${width ?? 'original'}', () async {
    final bytes = await rootBundle.load(template.asset);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      targetWidth: width,
      allowUpscaling: false,
    );
    try {
      final image = (await codec.getNextFrame()).image;
      if (width == null &&
          (image.width != template.sourceSize.width ||
              image.height != template.sourceSize.height)) {
        image.dispose();
        throw StateError('Original slide dimensions changed');
      }
      return image;
    } finally {
      codec.dispose();
    }
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
    required this.fontFamily,
  });
  final String role, value;
  final Rect rect;
  final double fontSize;
  final int color, fontWeight;

  /// Changed fields use a bundled substitute; the original source font is
  /// unknown. Unchanged fields remain the exact source bitmap glyphs.
  final String fontFamily;
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
    this.fontFamily,
    this.clearColor,
  );
  final String role, value, original, fontFamily;
  final Rect bounds;
  final double fontSize;
  final int weight, color, clearColor;
  bool get changed => value.trim() != original;
}

List<_Field> _fields(WorkoutModule module) {
  final template = originalSlideTemplate(module.designStyle?.originalTemplate)!;
  final rows = originalSlideLines(module.text);
  return [
    _Field(
      'title',
      template.fixedTitle
          ? module.name.trim()
          : module.name.trim().toUpperCase(),
      template.title,
      template.titleBounds,
      template.titleFontSize,
      template.fixedTitle ? 700 : 400,
      template.fixedTitle ? template.accentColor : 0xFFFFFFFF,
      template.fixedTitle ? template.fontFamily : 'RacingSansOne',
      template.fixedTitle ? template.backgroundColor : template.accentColor,
    ),
    _Field(
      'subtitle',
      module.designSubtitle.trim(),
      template.subtitle,
      template.subtitleBounds,
      template.subtitleFontSize,
      template.fixedTitle ? 400 : 800,
      template.fixedTitle ? template.textColor : template.accentColor,
      template.fontFamily,
      template.backgroundColor,
    ),
    for (var i = 0; i < template.maxLines; i++)
      _Field(
        'body',
        i < rows.length ? rows[i] : '',
        template.lines[i],
        template.exerciseBounds[i],
        template.bodyFontSize,
        template.bodyWeight,
        template.textColor,
        template.fontFamily,
        template.backgroundColor,
      ),
  ];
}

TextPainter _text(_Field field, double size, {bool fixed = false}) =>
    TextPainter(
      text: TextSpan(
        text: field.value,
        style: TextStyle(
          fontFamily: field.fontFamily,
          fontSize: size,
          fontWeight: FontWeight.values[field.weight ~/ 100 - 1],
          color: Color(field.color),
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: fixed ? null : 1,
    )..layout(maxWidth: fixed ? field.bounds.width : double.infinity);

({TextPainter painter, double fontSize}) _fit(
  _Field field, {
  bool fixed = false,
}) {
  var size = field.fontSize;
  var painter = _text(field, size, fixed: fixed);
  final factor = math.min(
    1.0,
    math.min(
      field.bounds.width / math.max(1, painter.width),
      field.bounds.height / math.max(1, painter.height),
    ),
  );
  if (!fixed && factor < 1) {
    size *= factor;
    painter.dispose();
    painter = _text(field, size);
  }
  return (painter: painter, fontSize: size);
}

/// Synchronous geometry, in the standard 1920×1080 output coordinate space.
OriginalSlideMetrics measureOriginalSlide(
  WorkoutModule module, {
  bool fixedTypography = false,
}) {
  final template = originalSlideTemplate(module.designStyle?.originalTemplate)!;
  final target = originalSlideImageRect(
    originalSlideOutputSize,
    sourceSize: template.sourceSize,
  );
  final scale = target.width / template.sourceSize.width;
  final runs = <OriginalSlideTextBounds>[];
  var warning = originalSlideValidationError(module);
  for (final field in _fields(module)) {
    if (field.value.isEmpty) continue;
    final fitted = _fit(field, fixed: fixedTypography);
    final rect = Rect.fromLTWH(
      target.left + field.bounds.left * scale,
      target.top + (field.bounds.center.dy - fitted.painter.height / 2) * scale,
      fitted.painter.width * scale,
      fitted.painter.height * scale,
    );
    final fontSize = (field.changed ? fitted.fontSize : field.fontSize) * scale;
    if (field.changed &&
        (fontSize < 36 ||
            (fixedTypography &&
                (fitted.painter.height > field.bounds.height ||
                    fitted.painter.width > field.bounds.width)))) {
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
        fontFamily: field.fontFamily,
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
  ui.Image image, {
  bool fixedTypography = false,
}) {
  // Incomplete editor drafts may still preview. The validation/metrics warning
  // blocks applying or exporting overflow, while the source module keeps all
  // entered content. Only this fixed recipe's four slots are drawn here.
  if (!isOriginalSlideTemplate(module)) {
    throw ArgumentError('Unknown original slide template');
  }
  final template = originalSlideTemplate(module.designStyle?.originalTemplate)!;
  final target = originalSlideImageRect(size, sourceSize: template.sourceSize);
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = Color(template.backgroundColor),
  );
  canvas.save();
  canvas.translate(target.left, target.top);
  final scale = target.width / template.sourceSize.width;
  canvas.scale(scale);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Offset.zero & template.sourceSize,
    Paint()..filterQuality = FilterQuality.medium,
  );
  // Empty slots also remove their baked number. Every remaining number and
  // class mark is still painted directly from the original image.
  final lines = originalSlideLines(module.text);
  for (var i = lines.length; i < template.numberBounds.length; i++) {
    canvas.drawRect(
      template.numberBounds[i],
      Paint()
        ..color = Color(template.backgroundColor)
        ..isAntiAlias = false,
    );
  }
  for (final field in _fields(module)) {
    if (!field.changed) continue;
    final clear = Paint()
      ..color = Color(field.clearColor)
      ..isAntiAlias = false;
    canvas.drawRect(field.bounds, clear);
    if (field.value.isEmpty) continue;
    final fitted = _fit(field, fixed: fixedTypography);
    canvas.save();
    if (!fixedTypography) canvas.clipRect(field.bounds);
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
