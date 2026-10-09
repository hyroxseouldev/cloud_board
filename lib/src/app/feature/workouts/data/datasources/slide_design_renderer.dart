import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/original_slide_renderer.dart';

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
    this.textRuns = const [],
    this.decorationRuns = const [],
    this.warning,
  });
  final double minFontSize;
  final int columns;
  final Rect? timerExclusion;
  final Rect textBounds;
  final List<SlideDesignSectionBounds> sections;

  /// Exact painted content bounds, excluding decorative motifs and shapes.
  final List<SlideDesignTextBounds> textRuns;
  final List<SlideDesignTextBounds> decorationRuns;
  final String? warning;
  bool get readable => warning == null;
}

class SlideDesignTextBounds {
  const SlideDesignTextBounds({
    required this.role,
    required this.value,
    required this.rect,
    required this.fontSize,
    required this.fontFamily,
    required this.fontWeight,
    required this.color,
  });
  final String role, value, fontFamily;
  final Rect rect;
  final double fontSize;
  final int fontWeight;
  final int color;
}

/// Uses exactly the same measured text and bounds as preview and PNG export.
/// A warning prevents new drafts from being added at unreadably small sizes;
/// old saved artwork can still render in full without dropping any content.
SlideDesignLayoutMetrics measureSlideDesign(WorkoutModule module) {
  if (!isOriginalSlideTemplate(module)) return _createPlan(module).metrics;
  final original = measureOriginalSlide(module);
  return SlideDesignLayoutMetrics(
    minFontSize: original.minFontSize,
    columns: 1,
    timerExclusion: null,
    textBounds: original.textBounds,
    sections: [
      SlideDesignSectionBounds(
        heading: '',
        lines: slideDesignLines(module.text),
        rect: original.textBounds,
      ),
    ],
    textRuns: [
      for (final run in original.textRuns)
        SlideDesignTextBounds(
          role: run.role,
          value: run.value,
          rect: run.rect,
          fontSize: run.fontSize,
          fontFamily: run.fontFamily,
          fontWeight: run.fontWeight,
          color: run.color,
        ),
    ],
    warning: original.warning,
  );
}

class _DrawText {
  const _DrawText(
    this.value,
    this.rect,
    this.fontSize, {
    this.accent = false,
    this.style,
    this.role = 'body',
    this.align = TextAlign.left,
  });
  final String value;
  final Rect rect;
  final double fontSize;
  final bool accent;
  final TextStyle? style;
  final String role;
  final TextAlign align;
}

class _Plan {
  const _Plan(
    this.metrics,
    this.text,
    this.cards, {
    this.shapes = const [],
    this.motifs = const [],
  });
  final SlideDesignLayoutMetrics metrics;
  final List<_DrawText> text;
  final List<Rect> cards;
  final List<_DrawShape> shapes;
  final List<_DrawText> motifs;
}

class _DrawShape {
  const _DrawShape(this.rect, this.color, {this.radius = 0});
  final Rect rect;
  final Color color;
  final double radius;
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
  if (isStudioSlideDesign(module)) return _measureStudioPlan(module);
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

String _studioFamily(WorkoutModule module) =>
    module.designStyle?.family ?? 'banner';

Color _background(WorkoutModule module) => Color(
  module.designBackgroundColor ??
      (isStudioSlideDesign(module) &&
              ['banner', 'cards'].contains(_studioFamily(module))
          ? 0xFFFFFFFF
          : 0xFF000000),
);

Color _foreground(WorkoutModule module) => Color(
  module.designTextColor ??
      (isStudioSlideDesign(module) &&
              ['banner', 'cards'].contains(_studioFamily(module))
          ? 0xFF111318
          : 0xFFFFFFFF),
);

Color _onColor(Color color) =>
    color.computeLuminance() > 0.46 ? const Color(0xFF111318) : Colors.white;

double _contrast(Color a, Color b) {
  final first = a.computeLuminance(), second = b.computeLuminance();
  return (math.max(first, second) + .05) / (math.min(first, second) + .05);
}

Color _legibleAccent(Color accent, Color background, Color foreground) =>
    _contrast(accent, background) >= 3
    ? accent
    : _contrast(foreground, background) >= 3
    ? foreground
    : _onColor(background);

int _studioWeight(
  WorkoutModule module, {
  bool title = false,
  bool label = false,
}) => title
    ? module.designStyle?.titleWeight ?? 900
    : label
    ? 700
    : module.designFontWeight;

TextStyle _studioStyle(
  WorkoutModule module,
  double size,
  Color color, {
  bool title = false,
  bool label = false,
}) => TextStyle(
  fontFamily: module.designStyle?.fontFamily == 'serif'
      ? 'NotoSerifKR'
      : 'Pretendard',
  // Both families are bundled, including Hangul, so previews and exports never
  // depend on whichever serif face happens to be installed on the device.
  fontFamilyFallback: const ['Pretendard', 'NotoSerifKR'],
  fontSize: size,
  fontWeight:
      FontWeight.values[((_studioWeight(module, title: title, label: label) /
                      100)
                  .round() -
              1)
          .clamp(0, 8)],
  fontVariations: module.designStyle?.fontFamily == 'serif'
      ? [
          ui.FontVariation(
            'wght',
            _studioWeight(module, title: title, label: label).toDouble(),
          ),
        ]
      : null,
  fontStyle: title
      ? (_studioFamily(module) == 'banner'
            ? FontStyle.italic
            : FontStyle.normal)
      : label
      ? FontStyle.normal
      : module.designItalic
      ? FontStyle.italic
      : FontStyle.normal,
  color: color,
  height: (title ? 1.06 : 1.18) * module.designSpacing.clamp(0.8, 1.5),
);

TextPainter _styledPainter(
  String value,
  TextStyle style,
  double width, {
  TextAlign align = TextAlign.left,
}) => TextPainter(
  text: TextSpan(text: value, style: style),
  textDirection: TextDirection.ltr,
  textAlign: align,
)..layout(minWidth: math.max(1, width), maxWidth: math.max(1, width));

double _studioHeight(String value, TextStyle style, double width) {
  final painter = _styledPainter(value, style, width);
  try {
    return painter.height;
  } finally {
    painter.dispose();
  }
}

_DrawText _fitStudioText(
  WorkoutModule module,
  String value,
  Rect area,
  double maxSize,
  Color color, {
  required String role,
  bool title = false,
  bool label = false,
  TextAlign align = TextAlign.left,
}) {
  var size = maxSize;
  var style = _studioStyle(module, size, color, title: title, label: label);
  var height = _studioHeight(value, style, area.width);
  while (size > 8 && height > area.height) {
    size -= 2;
    style = _studioStyle(module, size, color, title: title, label: label);
    height = _studioHeight(value, style, area.width);
  }
  return _DrawText(
    value,
    Rect.fromLTWH(area.left, area.top, area.width, height),
    size,
    style: style,
    role: role,
    align: align,
  );
}

_DrawText _fitStudioMotif(
  WorkoutModule module,
  String value,
  Rect area,
  Color color,
) {
  final trimmed = value.trim();
  // Two ideographs can deliberately stack like a poster seal. Latin words and
  // phrases stay whole; their size, never their spelling, adapts to the field.
  final text = RegExp(r'^[\u3400-\u9FFF]{2}$').hasMatch(trimmed)
      ? '${String.fromCharCode(trimmed.runes.first)}\n${String.fromCharCode(trimmed.runes.last)}'
      : trimmed.replaceAll(RegExp(r'\s+'), ' ');
  var size = 420.0;
  var height = 0.0;
  late TextStyle style;
  while (true) {
    style = _studioStyle(module, size, color, title: true);
    final natural = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = natural.width;
    height = natural.height;
    natural.dispose();
    if ((width + 4 <= area.width && height <= area.height) || size <= 8) break;
    size -= 2;
  }
  return _DrawText(
    text,
    Rect.fromLTWH(
      area.left,
      area.top + math.max(0, area.height - height) / 2,
      area.width,
      height,
    ),
    size,
    style: style,
    role: 'motif',
    align: TextAlign.center,
  );
}

/// Studio layouts share measurements with the export painter but deliberately
/// do not change the v1/v2 renderer. Content, headings and decoration remain
/// separate: no exercise is inferred from a motif or removed to make it fit.
_Plan _measureStudioPlan(WorkoutModule module) {
  final family = _studioFamily(module);
  final banner = family == 'banner';
  final editorial = family == 'editorial';
  final cards = family == 'cards' || module.designLayout == 'cards';
  final focus = family == 'focus';
  final exclusion = slideTimerGeometry(
    module,
    SlideDesignPainter.size,
  ).exclusion;
  final region = _textRegion(exclusion);
  final foreground = _foreground(module);
  final background = _background(module);
  final accent = Color(module.designAccentColor ?? 0xFFFF343A);
  final accentText = _legibleAccent(accent, background, foreground);
  final titleColor = Color(
    module.designStyle?.titleColor ??
        (banner ? _onColor(accent).toARGB32() : accent.toARGB32()),
  );
  final text = <_DrawText>[];
  final shapes = <_DrawShape>[];
  final motifs = <_DrawText>[];
  final titleInset = focus ? 38.0 : 0.0;
  final contentLeft = region.left + titleInset;
  final contentWidth = math.max(1.0, region.width - titleInset);
  final label = module.designHeaderLabel.trim();
  final labelWidth = label.isEmpty
      ? 0.0
      : contentWidth * (banner ? 0.29 : 0.25);
  final titleTop = region.top + (editorial ? 32 : 0);
  final headerMaxHeight = math.min(144.0, region.height * 0.23);
  final title = _fitStudioText(
    module,
    module.name,
    Rect.fromLTWH(
      contentLeft,
      titleTop,
      math.max(1, contentWidth - labelWidth - (label.isEmpty ? 0 : 36)),
      headerMaxHeight,
    ),
    editorial
        ? 132
        : focus
        ? 112
        : banner
        ? 100
        : 92,
    titleColor,
    role: 'title',
    title: true,
  );
  text.add(title);
  var headerBottom = title.rect.bottom;
  if (label.isNotEmpty) {
    final labelRun = _fitStudioText(
      module,
      label,
      Rect.fromLTWH(
        region.right - labelWidth,
        titleTop + 12,
        labelWidth,
        headerMaxHeight - 12,
      ),
      banner ? 52 : 38,
      banner ? titleColor : foreground,
      role: 'headerLabel',
      label: true,
      align: TextAlign.right,
    );
    text.add(labelRun);
    headerBottom = math.max(headerBottom, labelRun.rect.bottom);
  }
  if (banner) {
    // The colored bar can meet the canvas edge; content always stays inside
    // the measured safe region, including when a timer occupies the top edge.
    shapes.add(
      _DrawShape(
        Rect.fromLTRB(
          0,
          math.max(0, region.top - 64),
          SlideDesignPainter.size.width,
          headerBottom + 28,
        ),
        accent,
      ),
    );
  } else if (focus) {
    shapes.add(
      _DrawShape(
        Rect.fromLTWH(
          region.left,
          region.top + 4,
          8,
          math.min(region.height, headerBottom - region.top + 100),
        ),
        accent,
        radius: 4,
      ),
    );
  } else if (cards) {
    shapes.add(
      _DrawShape(
        Rect.fromLTWH(region.left, headerBottom + 24, region.width, 3),
        accent,
      ),
    );
  }

  var bodyTop =
      headerBottom +
      (editorial
          ? 44
          : banner
          ? 64
          : 40);
  final subtitle = module.designSubtitle.trim();
  if (subtitle.isNotEmpty) {
    final subtitleRun = _fitStudioText(
      module,
      subtitle,
      Rect.fromLTWH(
        contentLeft,
        bodyTop,
        contentWidth,
        math.min(136.0, region.height * .2),
      ),
      banner
          ? 66
          : editorial
          ? 70
          : focus
          ? 66
          : 52,
      editorial ? foreground : accentText,
      role: 'subtitle',
      label: !editorial,
    );
    text.add(subtitleRun);
    bodyTop = subtitleRun.rect.bottom + (editorial ? 42 : 38);
  }

  final sourceSections = parseSlideDesignSections(module.text);
  // A plain list becomes one card per exercise. Explicit sections remain
  // intact, in their original order, with the heading inside each card.
  final sections =
      cards &&
          sourceSections.length == 1 &&
          sourceSections.single.heading.isEmpty
      ? [
          for (final line in sourceSections.single.lines)
            (heading: '', lines: [line]),
        ]
      : sourceSections;
  final columns = module.designLayout == 'columns'
      ? 2
      : cards && sections.length > 1
      ? (sections.length > 4 && region.width >= 1500 ? 3 : 2)
      : 1;
  final arranged = cards ? sections : _splitLargeSection(sections, columns);
  final columnGap = cards ? 24.0 : 44.0;
  final bodyWidth = math.max(1.0, region.width - titleInset);
  final columnWidth = math.max(
    1.0,
    (bodyWidth - (columns - 1) * columnGap) / columns,
  );
  final padding = cards ? 28.0 : 0.0;
  final numbered = slideDesignKind(module) == 'numbered';
  final hasMotif =
      editorial && (module.designStyle?.motif.trim().isNotEmpty ?? false);
  // Posters reserve a visual field for their own motif. It is never a global
  // brand default and cannot become an extra exercise or a timer instruction.
  final motifBodyWidth = hasMotif && columns == 1
      ? columnWidth * .76
      : columnWidth;
  final availableHeight = math.max(1.0, region.bottom - bodyTop);
  // Short daily notes should fill the artwork, not inherit the density of a
  // six-station reference. Measure down from display-sized text for every note.
  var fontSize = cards ? 104.0 : 112.0;
  var heights = <double>[];
  var partition = <List<int>>[];
  var fits = false;
  var rowGap = 0.0;
  var sectionGap = 0.0;
  var badgeSize = 0.0;
  var lineWidth = 1.0;
  final gridRows = math.max(1, (arranged.length / columns).ceil());
  var gridCellHeight = 0.0;
  for (; fontSize >= 8; fontSize -= 2) {
    final bodyStyle = _studioStyle(module, fontSize, foreground);
    final headingStyle = _studioStyle(
      module,
      fontSize * 1.04,
      accentText,
      label: true,
    );
    badgeSize = numbered ? fontSize * 1.2 : 0;
    lineWidth = math.max(
      1,
      motifBodyWidth - padding * 2 - (numbered ? badgeSize + 34 : 0),
    );
    rowGap = fontSize * (banner ? .45 : .32) * module.designSpacing;
    sectionGap = cards ? 24 : fontSize * .55;
    heights = [
      for (final section in arranged)
        padding * 2 +
            (section.heading.isEmpty
                ? 0
                : _studioHeight(
                        section.heading,
                        headingStyle,
                        columnWidth - padding * 2,
                      ) +
                      fontSize * .32) +
            section.lines.fold<double>(
              0,
              (sum, line) =>
                  sum +
                  math.max(
                    badgeSize,
                    _studioHeight(line, bodyStyle, lineWidth),
                  ),
            ) +
            math.max(0, section.lines.length - 1) * rowGap,
    ];
    partition = _partition(heights, columns, sectionGap);
    if (cards) {
      gridCellHeight = math.max(
        1,
        (availableHeight - (gridRows - 1) * sectionGap) / gridRows,
      );
      fits = heights.every((height) => height <= gridCellHeight);
    } else {
      final requiredHeight = partition.fold<double>(
        0,
        (maxHeight, indices) => math.max(
          maxHeight,
          indices.fold<double>(0, (sum, i) => sum + heights[i]) +
              math.max(0, indices.length - 1) * sectionGap,
        ),
      );
      fits = requiredHeight <= availableHeight;
    }
    if (fits || fontSize == 8) break;
  }

  // Distribute the small remainder between rows, keeping both the first and
  // last exercise aligned with the available body region. Dense notes still
  // keep every source row and fail the readability check rather than dropping it.
  if (!cards &&
      columns == 1 &&
      arranged.length == 1 &&
      arranged.single.lines.length >= 3 &&
      fits) {
    final gaps = arranged.single.lines.length - 1;
    final extra = math.max(0.0, availableHeight - heights.single);
    rowGap += extra / gaps;
    heights[0] += extra;
  }
  final placements = <({int index, int column, double top, double height})>[];
  if (cards) {
    // Row-major order is explicit for a card grid: 1, 2 / 3, 4. Equal cells
    // occupy the complete body region and keep short cards from clustering up top.
    for (var index = 0; index < arranged.length; index++) {
      placements.add((
        index: index,
        column: index % columns,
        top: bodyTop + (index ~/ columns) * (gridCellHeight + sectionGap),
        height: gridCellHeight,
      ));
    }
  } else {
    for (final (column, indices) in partition.indexed) {
      var y = bodyTop;
      for (final index in indices) {
        placements.add((
          index: index,
          column: column,
          top: y,
          height: heights[index],
        ));
        y += heights[index] + sectionGap;
      }
    }
  }
  final bounds = <SlideDesignSectionBounds>[];
  var lineNumber = 0;
  for (final placement in placements) {
    final index = placement.index;
    final section = arranged[index];
    final x = contentLeft + placement.column * (columnWidth + columnGap);
    final rect = Rect.fromLTWH(x, placement.top, columnWidth, placement.height);
    bounds.add(
      SlideDesignSectionBounds(
        heading: section.heading,
        lines: section.lines,
        rect: rect,
      ),
    );
    if (cards) {
      shapes.add(
        _DrawShape(
          rect,
          Color.alphaBlend(accent.withValues(alpha: .075), background),
          radius: 18,
        ),
      );
      shapes.add(
        _DrawShape(
          Rect.fromLTWH(x, rect.top, 5, rect.height),
          accent,
          radius: 2.5,
        ),
      );
    }
    var y =
        rect.top +
        padding +
        (cards ? math.max(0, rect.height - heights[index]) / 2 : 0);
    if (section.heading.isNotEmpty) {
      final style = _studioStyle(
        module,
        fontSize * 1.04,
        accentText,
        label: true,
      );
      final height = _studioHeight(
        section.heading,
        style,
        columnWidth - padding * 2,
      );
      text.add(
        _DrawText(
          section.heading,
          Rect.fromLTWH(x + padding, y, columnWidth - padding * 2, height),
          fontSize * 1.04,
          style: style,
          role: 'section',
        ),
      );
      y += height + fontSize * .32;
    }
    for (final (rowIndex, line) in section.lines.indexed) {
      lineNumber++;
      final style = _studioStyle(module, fontSize, foreground);
      final height = _studioHeight(line, style, lineWidth);
      final rowHeight = math.max(badgeSize, height);
      if (numbered) {
        final badge = Rect.fromLTWH(x + padding, y, badgeSize, badgeSize);
        shapes.add(_DrawShape(badge, accent, radius: banner ? 8 : 12));
        final badgeStyle = _studioStyle(
          module,
          fontSize * .78,
          _onColor(accent),
          label: true,
        );
        final numberHeight = _studioHeight(
          '$lineNumber',
          badgeStyle,
          badgeSize,
        );
        text.add(
          _DrawText(
            '$lineNumber',
            Rect.fromLTWH(
              badge.left,
              badge.top + (badgeSize - numberHeight) / 2,
              badgeSize,
              numberHeight,
            ),
            fontSize * .78,
            style: badgeStyle,
            role: 'number',
            align: TextAlign.center,
          ),
        );
      }
      text.add(
        _DrawText(
          line,
          Rect.fromLTWH(
            x + padding + (numbered ? badgeSize + 34 : 0),
            y + (rowHeight - height) / 2,
            lineWidth,
            height,
          ),
          fontSize,
          style: style,
        ),
      );
      y += rowHeight + (rowIndex == section.lines.length - 1 ? 0 : rowGap);
    }
  }
  if (hasMotif) {
    final motifArea = Rect.fromLTWH(
      region.left + region.width * .53,
      region.top + 170,
      region.width * .47,
      math.max(1, region.height - 170),
    );
    motifs.add(
      _fitStudioMotif(
        module,
        module.designStyle!.motif,
        motifArea,
        accent.withValues(alpha: .13),
      ),
    );
  }
  final timerOnly =
      slideDesignKind(module) == 'interval' &&
      module.showTimer &&
      module.workSeconds > 0;
  final empty =
      sourceSections.every((section) => section.lines.isEmpty) && !timerOnly;
  final runs = [
    for (final item in text)
      SlideDesignTextBounds(
        role: item.role,
        value: item.value,
        rect: item.rect,
        fontSize: item.fontSize,
        fontFamily: item.style!.fontFamily!,
        fontWeight: item.style!.fontWeight!.value,
        color: item.style!.color!.toARGB32(),
      ),
  ];
  final contentRuns = runs.where((run) => run.role != 'number').toList();
  final minFont = contentRuns.fold<double>(
    double.infinity,
    (value, run) => math.min(value, run.fontSize),
  );
  final contentFits = runs.every(
    (run) =>
        run.rect.left >= region.left - .01 &&
        run.rect.top >= region.top - .01 &&
        run.rect.right <= region.right + .01 &&
        run.rect.bottom <= region.bottom + .01 &&
        (exclusion == null || !run.rect.overlaps(exclusion)),
  );
  final readable =
      fits &&
      contentFits &&
      minFont >= slideDesignMinimumFontSize &&
      title.fontSize >= 48 &&
      region.width >= 480 &&
      !empty;
  return _Plan(
    SlideDesignLayoutMetrics(
      minFontSize: minFont,
      columns: columns,
      timerExclusion: exclusion,
      textBounds: region,
      sections: List.unmodifiable(bounds),
      textRuns: List.unmodifiable(runs),
      decorationRuns: List.unmodifiable([
        for (final item in motifs)
          SlideDesignTextBounds(
            role: item.role,
            value: item.value,
            rect: item.rect,
            fontSize: item.fontSize,
            fontFamily: item.style!.fontFamily!,
            fontWeight: item.style!.fontWeight!.value,
            color: item.style!.color!.toARGB32(),
          ),
      ]),
      warning: readable
          ? null
          : empty
          ? '슬라이드에 넣을 운동 내용을 입력해 주세요.'
          : '글씨가 너무 작아져요. 배치를 바꾸거나 문장을 간결하게 다듬어 주세요. 타이머가 있다면 크기와 위치도 조절할 수 있어요.',
    ),
    text,
    const [],
    shapes: shapes,
    motifs: motifs,
  );
}

/// Shared preview/export painter. Editing and playback never call AI.
class SlideDesignPainter extends CustomPainter {
  const SlideDesignPainter(this.module, {this.originalImage});
  final WorkoutModule module;
  final ui.Image? originalImage;
  static const size = Size(1920, 1080);

  @override
  void paint(Canvas canvas, Size viewport) {
    if (isOriginalSlideTemplate(module)) {
      if (originalImage != null) {
        paintOriginalSlide(canvas, viewport, module, originalImage!);
      }
      return;
    }
    final plan = _createPlan(module);
    final background = _background(module);
    final foreground = _foreground(module);
    final accent = Color(module.designAccentColor ?? 0xFFFF343A);
    canvas.save();
    canvas.scale(viewport.width / size.width, viewport.height / size.height);
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    for (final item in plan.motifs) {
      final painter = _styledPainter(
        item.value,
        item.style!,
        item.rect.width,
        align: item.align,
      );
      try {
        painter.paint(canvas, item.rect.topLeft);
      } finally {
        painter.dispose();
      }
    }
    for (final shape in plan.shapes) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(shape.rect, Radius.circular(shape.radius)),
        Paint()..color = shape.color,
      );
    }
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
      final painter = item.style != null
          ? _styledPainter(
              item.value,
              item.style!,
              item.rect.width,
              align: item.align,
            )
          : _painter(
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
      module != oldDelegate.module ||
      originalImage != oldDelegate.originalImage;
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
  module.designStyle?.toJson(),
  module.designHeaderLabel,
  module.designSubtitle,
  slideDesignKind(module) == 'interval' && module.workSeconds > 0,
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
  final originalImage = isOriginalSlideTemplate(module)
      ? await loadOriginalSlideImage(module.designStyle!.originalTemplate!)
      : null;
  final recorder = ui.PictureRecorder();
  SlideDesignPainter(
    module,
    originalImage: originalImage,
  ).paint(Canvas(recorder), SlideDesignPainter.size);
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
