import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';

const slideDesignMinimumFontSize = 36.0;

/// Shared geometry for the live timer and the space left clear by the artwork.
class SlideTimerGeometry {
  const SlideTimerGeometry({
    required this.group,
    required this.timer,
    required this.sets,
  });
  final Rect group;
  final Rect? timer, sets;
  Rect? get exclusion => timer == null
      ? sets
      : sets == null
      ? timer
      : timer!.expandToInclude(sets!);
}

SlideTimerGeometry slideTimerGeometry(
  WorkoutModule module,
  Size viewport, {
  double? scale,
  double safeInset = 0,
}) {
  final appearance = module.appearance;
  final effectiveScale =
      scale ?? math.min(viewport.width / 1280, viewport.height / 720);
  final unit = effectiveScale * appearance.timerSize;
  final width = 232 * unit;
  final timerHeight = module.showTimer ? width : 0.0;
  final labelHeight = module.showSets ? 40 * unit : 0.0;
  final scaledLabelHeight = labelHeight * appearance.setsSize;
  final height = timerHeight + labelHeight;
  final insetX = viewport.width * safeInset;
  final insetY = viewport.height * safeInset;
  final anchorX = insetX + appearance.timerX * (viewport.width - 2 * insetX);
  final anchorY = insetY + appearance.timerY * (viewport.height - 2 * insetY);
  final left = (anchorX - width / 2).clamp(
    insetX,
    (viewport.width - insetX - width).clamp(insetX, double.infinity),
  );
  final maxTop = (viewport.height - insetY - height - 64 * effectiveScale)
      .clamp(insetY, double.infinity);
  final top = (anchorY - timerHeight / 2).clamp(insetY, maxTop);
  final labelTop =
      (top + timerHeight + appearance.setsOffsetY * viewport.height).clamp(
        insetY,
        (viewport.height - insetY - scaledLabelHeight - 64 * effectiveScale)
            .clamp(insetY, double.infinity),
      );
  return SlideTimerGeometry(
    group: Rect.fromLTWH(left, top, width, height),
    timer: module.showTimer
        ? Rect.fromLTWH(left, top, width, timerHeight)
        : null,
    sets: module.showSets
        ? Rect.fromLTWH(left, labelTop, width, scaledLabelHeight)
        : null,
  );
}

class SlideDesignSectionBounds {
  const SlideDesignSectionBounds({
    required this.heading,
    required this.lines,
    required this.rect,
  });
  final String heading;
  final List<String> lines;
  final Rect rect;
}

class SlideDesignLayoutMetrics {
  const SlideDesignLayoutMetrics({
    required this.minFontSize,
    required this.columns,
    required this.timerExclusion,
    required this.textBounds,
    required this.sections,
    this.warning,
  });
  final double minFontSize;
  final int columns;
  final Rect? timerExclusion;
  final Rect textBounds;
  final List<SlideDesignSectionBounds> sections;
  final String? warning;
  bool get readable => warning == null;
}

/// Uses exactly the same measured text and bounds as preview and PNG export.
/// A warning prevents new drafts from being added at unreadably small sizes;
/// old saved artwork can still render in full without dropping any content.
SlideDesignLayoutMetrics measureSlideDesign(WorkoutModule module) =>
    _createPlan(module).metrics;

class _DrawText {
  const _DrawText(this.value, this.rect, this.fontSize, {this.accent = false});
  final String value;
  final Rect rect;
  final double fontSize;
  final bool accent;
}

class _Plan {
  const _Plan(this.metrics, this.text, this.cards);
  final SlideDesignLayoutMetrics metrics;
  final List<_DrawText> text;
  final List<Rect> cards;
}

TextStyle _style(WorkoutModule module, double size, Color color) => TextStyle(
  fontFamily: 'Pretendard',
  fontSize: size,
  fontWeight: FontWeight
      .values[((module.designFontWeight / 100).round() - 1).clamp(0, 8)],
  fontStyle: module.designItalic ? FontStyle.italic : FontStyle.normal,
  color: color,
  height: 1.14 * module.designSpacing.clamp(0.8, 1.5),
);

TextPainter _painter(
  WorkoutModule module,
  String text,
  double fontSize,
  double width, [
  Color color = Colors.white,
]) => TextPainter(
  text: TextSpan(text: text, style: _style(module, fontSize, color)),
  textDirection: TextDirection.ltr,
)..layout(maxWidth: math.max(1, width));

double _textHeight(
  WorkoutModule module,
  String text,
  double size,
  double width,
) {
  final painter = _painter(module, text, size, width);
  try {
    return painter.height;
  } finally {
    painter.dispose();
  }
}

Rect _textRegion(Rect? exclusion) {
  const safe = Rect.fromLTRB(96, 64, 1824, 984);
  if (exclusion == null || !safe.overlaps(exclusion)) return safe;
  final blocked = exclusion.inflate(36).intersect(safe);
  final candidates = [
    Rect.fromLTRB(safe.left, safe.top, blocked.left, safe.bottom),
    Rect.fromLTRB(blocked.right, safe.top, safe.right, safe.bottom),
    Rect.fromLTRB(safe.left, safe.top, safe.right, blocked.top),
    Rect.fromLTRB(safe.left, blocked.bottom, safe.right, safe.bottom),
  ].where((rect) => rect.width > 0 && rect.height > 0).toList();
  if (candidates.isEmpty) return const Rect.fromLTWH(96, 64, 1, 1);
  candidates.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
  return candidates.first;
}

List<SlideDesignSection> _splitLargeSection(
  List<SlideDesignSection> sections,
  int columns,
) {
  // Plain legacy lists have no grouping to keep; a single section may continue
  // in the next column. Multiple named sections always remain intact.
  if (sections.length != 1 ||
      columns == 1 ||
      sections.single.lines.length < columns) {
    return sections;
  }
  final section = sections.single;
  final rows = (section.lines.length / columns).ceil();
  return [
    for (var i = 0; i < section.lines.length; i += rows)
      (
        heading: i == 0 ? section.heading : '',
        lines: section.lines.sublist(
          i,
          math.min(i + rows, section.lines.length),
        ),
      ),
  ];
}

/// Contiguous partitioning retains the source reading order while finding the
/// least crowded column; it never interleaves exercises from different blocks.
List<List<int>> _partition(List<double> heights, int columns, double gap) {
  if (heights.isEmpty) return List.generate(columns, (_) => []);
  final count = math.min(columns, heights.length);
  final sums = [0.0];
  for (final height in heights) {
    sums.add(sums.last + height + gap);
  }
  final costs = List.generate(
    count + 1,
    (_) => List.filled(heights.length + 1, double.infinity),
  );
  final cuts = List.generate(
    count + 1,
    (_) => List.filled(heights.length + 1, 0),
  );
  costs[0][0] = 0;
  for (var c = 1; c <= count; c++) {
    for (var n = c; n <= heights.length; n++) {
      for (var start = c - 1; start < n; start++) {
        final cost = math.max(costs[c - 1][start], sums[n] - sums[start] - gap);
        if (cost < costs[c][n]) {
          costs[c][n] = cost;
          cuts[c][n] = start;
        }
      }
    }
  }
  final result = <List<int>>[];
  var end = heights.length;
  for (var c = count; c > 0; c--) {
    final start = cuts[c][end];
    result.insert(0, List.generate(end - start, (i) => start + i));
    end = start;
  }
  return [...result, for (var c = count; c < columns; c++) <int>[]];
}

// Preview thumbnails, export, and the live canvas share the same immutable
// layout plan. Timer ticks do not repeat hundreds of text measurements.
final _layoutCache = <String, _Plan>{};

_Plan _createPlan(WorkoutModule module) {
  final key = _renderKey(module);
  final existing = _layoutCache.remove(key);
  if (existing != null) {
    _layoutCache[key] = existing;
    return existing;
  }
  final plan = _measurePlan(module);
  _layoutCache[key] = plan;
  while (_layoutCache.length > 32) {
    _layoutCache.remove(_layoutCache.keys.first);
  }
  return plan;
}

_Plan _measurePlan(WorkoutModule module) {
  final exclusion = slideTimerGeometry(
    module,
    SlideDesignPainter.size,
  ).exclusion;
  final region = _textRegion(exclusion);
  final sections = parseSlideDesignSections(module.text);
  final isCards = module.designLayout == 'cards';
  final candidateColumns = module.designLayout == 'columns'
      ? [2]
      : isCards
      ? [1, if (sections.length > 1) 2, if (sections.length > 2) 3]
      : [1, 2, 3];
  _Plan? best;
  for (final columns in candidateColumns) {
    final plan = _planColumns(
      module,
      sections,
      region,
      exclusion,
      columns,
      isCards,
    );
    // The large-text option keeps a simple reading path while comfortably
    // readable. Cards favor one short section per column when sizes are close.
    if (module.designLayout == 'auto' &&
        columns == 1 &&
        plan.metrics.readable &&
        plan.metrics.minFontSize >= 52) {
      return plan;
    }
    final columnPreference = isCards ? 2 : -2;
    if (best == null ||
        plan.metrics.minFontSize + columns * columnPreference >
            best.metrics.minFontSize +
                best.metrics.columns * columnPreference) {
      best = plan;
    }
  }
  return best!;
}

_Plan _planColumns(
  WorkoutModule module,
  List<SlideDesignSection> sourceSections,
  Rect region,
  Rect? exclusion,
  int columns,
  bool cards,
) {
  final sections = _splitLargeSection(sourceSections, columns);
  final gap = 36.0 * module.designSpacing;
  final padding = cards ? 22.0 : 0.0;
  final columnWidth = math.max(
    1.0,
    (region.width - (columns - 1) * gap) / columns,
  );
  final lineWidth = math.max(1.0, columnWidth - padding * 2);
  final titleHeightLimit = math.max(1.0, math.min(156.0, region.height * 0.22));
  var titleSize = 104.0;
  while (titleSize > 12 &&
      _textHeight(module, module.name, titleSize, region.width) >
          titleHeightLimit) {
    titleSize -= 2;
  }
  final titleHeight = _textHeight(module, module.name, titleSize, region.width);
  final bodyTop = region.top + titleHeight + 30;
  final availableHeight = math.max(1.0, region.bottom - bodyTop);
  final numbered = slideDesignKind(module) == 'numbered';
  final sectionSizes = <double>[];
  var fontSize = columns == 1 ? 76.0 : 62.0;
  var partition = <List<int>>[];
  var fits = false;
  // New drafts use the readable floor exposed by metrics. The lower fallback is
  // solely for already-saved dense slides, so a software update never hides text.
  for (; fontSize >= 8; fontSize -= 2) {
    sectionSizes.clear();
    var lineNumber = 0;
    for (final section in sections) {
      var height = padding * 2;
      if (section.heading.isNotEmpty) {
        height +=
            _textHeight(module, section.heading, fontSize * 1.06, lineWidth) +
            fontSize * 0.3;
      }
      for (final line in section.lines) {
        lineNumber++;
        final value = numbered && !RegExp(r'^\d+[.)]\s').hasMatch(line)
            ? '$lineNumber. $line'
            : line;
        height +=
            _textHeight(module, value, fontSize, lineWidth) + fontSize * 0.18;
      }
      sectionSizes.add(height);
    }
    partition = _partition(sectionSizes, columns, fontSize * 0.55);
    final maxHeight = partition.fold<double>(
      0,
      (max, indices) => math.max(
        max,
        indices.fold<double>(0, (sum, i) => sum + sectionSizes[i]) +
            math.max(0, indices.length - 1) * fontSize * 0.55,
      ),
    );
    fits = maxHeight <= availableHeight;
    if (fits || fontSize == 8) break;
  }
  final text = <_DrawText>[
    _DrawText(
      module.name,
      Rect.fromLTWH(region.left, region.top, region.width, titleHeight),
      titleSize,
      accent: true,
    ),
  ];
  final bounds = <SlideDesignSectionBounds>[];
  final cardRects = <Rect>[];
  var lineNumber = 0;
  for (final (column, indices) in partition.indexed) {
    var y = bodyTop;
    final x = region.left + column * (columnWidth + gap);
    for (final i in indices) {
      final section = sections[i];
      final sectionRect = Rect.fromLTWH(x, y, columnWidth, sectionSizes[i]);
      bounds.add(
        SlideDesignSectionBounds(
          heading: section.heading,
          lines: section.lines,
          rect: sectionRect,
        ),
      );
      if (cards) cardRects.add(sectionRect);
      y += padding;
      if (section.heading.isNotEmpty) {
        final height = _textHeight(
          module,
          section.heading,
          fontSize * 1.06,
          lineWidth,
        );
        text.add(
          _DrawText(
            section.heading,
            Rect.fromLTWH(x + padding, y, lineWidth, height),
            fontSize * 1.06,
            accent: true,
          ),
        );
        y += height + fontSize * 0.3;
      }
      for (final line in section.lines) {
        lineNumber++;
        final value = numbered && !RegExp(r'^\d+[.)]\s').hasMatch(line)
            ? '$lineNumber. $line'
            : line;
        final height = _textHeight(module, value, fontSize, lineWidth);
        text.add(
          _DrawText(
            value,
            Rect.fromLTWH(x + padding, y, lineWidth, height),
            fontSize,
            accent:
                sourceSections.every((s) => s.heading.isEmpty) &&
                lineNumber.isOdd,
          ),
        );
        y += height + fontSize * 0.18;
      }
      y += padding + fontSize * 0.55;
    }
  }
  final timerOnly =
      slideDesignKind(module) == 'interval' &&
      module.showTimer &&
      module.workSeconds > 0;
  final empty =
      sourceSections.every((section) => section.lines.isEmpty) && !timerOnly;
  final readable =
      fits &&
      fontSize >= slideDesignMinimumFontSize &&
      titleSize >= 48 &&
      region.width >= 480 &&
      !empty;
  return _Plan(
    SlideDesignLayoutMetrics(
      minFontSize: math.min(fontSize, titleSize),
      columns: columns,
      timerExclusion: exclusion,
      textBounds: region,
      sections: List.unmodifiable(bounds),
      warning: readable
          ? null
          : empty
          ? '슬라이드에 넣을 운동 내용을 입력해 주세요.'
          : '글씨가 너무 작아져요. 배치를 바꾸거나 문장을 간결하게 다듬어 주세요. 타이머가 있다면 크기와 위치도 조절할 수 있어요.',
    ),
    text,
    cardRects,
  );
}

/// Shared preview/export painter. Editing and playback never call AI.
class SlideDesignPainter extends CustomPainter {
  const SlideDesignPainter(this.module);
  final WorkoutModule module;
  static const size = Size(1920, 1080);

  @override
  void paint(Canvas canvas, Size viewport) {
    final plan = _createPlan(module);
    final background = Color(module.designBackgroundColor ?? 0xFF000000);
    final foreground = Color(module.designTextColor ?? 0xFFFFFFFF);
    final accent = Color(module.designAccentColor ?? 0xFFFF343A);
    canvas.save();
    canvas.scale(viewport.width / size.width, viewport.height / size.height);
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    for (final rect in plan.cards) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(22)),
        Paint()
          ..color = Color.alphaBlend(
            foreground.withValues(alpha: 0.09),
            background,
          ),
      );
    }
    for (final item in plan.text) {
      final painter = _painter(
        module,
        item.value,
        item.fontSize,
        item.rect.width,
        item.accent ? accent : foreground,
      );
      try {
        painter.paint(canvas, item.rect.topLeft);
      } finally {
        painter.dispose();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SlideDesignPainter oldDelegate) =>
      module != oldDelegate.module;
}

// Only visual inputs participate: timer progression and module IDs never trigger
// another expensive 1920×1080 PNG render. Bounded to avoid keeping full libraries.
final _renderCache = <String, Future<String>>{};
String _renderKey(WorkoutModule module) => jsonEncode([
  module.name,
  module.text,
  module.designTemplate,
  module.designLayout,
  module.designBackgroundColor,
  module.designTextColor,
  module.designAccentColor,
  module.designFontWeight,
  module.designItalic,
  module.designSpacing,
  module.showTimer,
  module.showSets,
  module.appearance.timerX,
  module.appearance.timerY,
  module.appearance.timerSize,
  module.appearance.setsOffsetY,
  module.appearance.setsSize,
]);

Future<String> renderSlideDesign(WorkoutModule module) async {
  if (!hasSlideDesign(module)) return module.imageSource;
  final error = slideDesignError(module);
  if (error != null) throw FormatException(error);
  final key = _renderKey(module);
  final existing = _renderCache.remove(key);
  if (existing != null) {
    _renderCache[key] = existing;
    return existing;
  }
  final pending = _renderSlideDesign(module);
  _renderCache[key] = pending;
  while (_renderCache.length > 8) {
    _renderCache.remove(_renderCache.keys.first);
  }
  try {
    return await pending;
  } catch (_) {
    if (identical(_renderCache[key], pending)) _renderCache.remove(key);
    rethrow;
  }
}

Future<String> _renderSlideDesign(WorkoutModule module) async {
  final recorder = ui.PictureRecorder();
  SlideDesignPainter(module).paint(Canvas(recorder), SlideDesignPainter.size);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(1920, 1080);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const FormatException('슬라이드 이미지를 만들지 못했습니다.');
      return 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

Future<WorkoutModule> prepareSlideDesign(WorkoutModule module) async {
  if (!hasSlideDesign(module)) return module;
  return module.copyWith(
    imageSource: await renderSlideDesign(module),
    appearance: module.appearance.copyWith(showTitle: false, showBody: false),
  );
}
